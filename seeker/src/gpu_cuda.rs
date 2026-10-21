//! Locally added CUDA backend. Fixed SM86 CUBIN, only NVIDIA driver required.
//! Every submitted GPU hit is checked again by main.rs using the CPU reference.
use sha2::{Digest,Sha512};
use std::{collections::VecDeque,ffi::{c_void,CString},ptr,time::Instant};
type Handle=*mut c_void;
#[link(name="nvcuda",kind="raw-dylib")]
extern "system" {
    fn cuInit(flags:u32)->i32;
    fn cuDeviceGet(device:*mut i32,ordinal:i32)->i32;
    fn cuDeviceGetName(name:*mut i8,len:i32,device:i32)->i32;
    fn cuCtxCreate_v2(ctx:*mut Handle,flags:u32,device:i32)->i32;
    fn cuCtxDestroy_v2(ctx:Handle)->i32;
    fn cuModuleLoadData(module:*mut Handle,image:*const c_void)->i32;
    fn cuModuleUnload(module:Handle)->i32;
    fn cuModuleGetFunction(func:*mut Handle,module:Handle,name:*const i8)->i32;
    fn cuMemAlloc_v2(address:*mut u64,size:usize)->i32;
    fn cuMemFree_v2(address:u64)->i32;
    fn cuMemsetD32Async(address:u64,value:u32,count:usize,stream:Handle)->i32;
    fn cuMemcpyHtoD_v2(address:u64,data:*const c_void,size:usize)->i32;
    fn cuMemcpyDtoH_v2(data:*mut c_void,address:u64,size:usize)->i32;
    fn cuMemcpyDtoHAsync_v2(data:*mut c_void,address:u64,size:usize,stream:Handle)->i32;
    fn cuMemHostAlloc(data:*mut Handle,size:usize,flags:u32)->i32;
    fn cuMemFreeHost(data:Handle)->i32;
    fn cuStreamCreate(stream:*mut Handle,flags:u32)->i32;
    fn cuStreamSynchronize(stream:Handle)->i32;
    fn cuStreamDestroy_v2(stream:Handle)->i32;
    fn cuLaunchKernel(func:Handle,gx:u32,gy:u32,gz:u32,bx:u32,by:u32,bz:u32,shared:u32,stream:Handle,args:*mut *mut c_void,extra:*mut *mut c_void)->i32;
}
fn check(code:i32,label:&str)->Result<(),String>{if code==0{Ok(())}else{Err(format!("CUDA {label}: {code}"))}}
fn cstr(s:&str)->CString{CString::new(s).unwrap()}
fn naf(scalar:&[u8;32])->[u8;256]{
    let window=5;
    assert!((2..=5).contains(&window));
    let mut n=[0u8;33];n[..32].copy_from_slice(scalar);let mut digits=[0;256];
    for d in &mut digits{
        if n[0]&1!=0{
            let raw=n[0]&((1<<window)-1);let v=if raw<(1<<(window-1)){raw as i16}else{raw as i16-(1i16<<window)};
            *d=v as i8 as u8;
            if v>0{n[0]-=v as u8}else{let mut c=(-v)as u16;for b in &mut n{let x=*b as u16+c;*b=x as u8;c=x>>8;if c==0{break}}}
        }
        for i in 0..32{n[i]=(n[i]>>1)|(n[i+1]<<7)}n[32]>>=1;
    }digits
}
// Key-dependent schedules remain in process memory; never log or persist them.
fn unpacked_scalar_digits(scalar: &[u8;32])->[u8;256] {
    use curve25519_dalek::scalar::Scalar;
    let folded=Scalar::from_bytes_mod_order(*scalar)*Scalar::from(8u64);
    let initial=naf(&folded.to_bytes());
    fn cost(d:&[u8;256])->usize {
        let top=d.iter().rposition(|&x|x!=0).unwrap_or(0);
        top*52+d.iter().filter(|&&x|x!=0).count().saturating_sub(1)*80
    }
    fn plus(a:[u8;32], b:&[u8;32])->Option<[u8;32]> {
        let mut out=[0u8;32];let mut carry=0u16;
        for i in 0..32 {let t=a[i]as u16+b[i]as u16+carry;out[i]=t as u8;carry=t>>8;}
        if carry!=0 || out[31]&128!=0 {None} else {Some(out)}
    }
    // L = 2^252 + 27742317777372353535851937790883648493, little endian.
    let order:[u8;32]=[0xed,0xd3,0xf5,0x5c,0x1a,0x63,0x12,0x58,0xd6,0x9c,0xf7,0xa2,0xde,0xf9,0xde,0x14,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0x10];
    let mut best=initial;let mut best_cost=cost(&best);
    for (first,negative) in [(folded.to_bytes(),false),((-folded).to_bytes(),true)] {
        let mut bytes=first;
        for _ in 0..8 {
            let mut candidate=naf(&bytes);
            if negative {for d in &mut candidate {*d=(*d as i8).wrapping_neg()as u8;}}
            let c=cost(&candidate);
            if candidate.iter().any(|&d|d!=0) && c<best_cost {best=candidate;best_cost=c;}
            match plus(bytes,&order) {Some(next)=>bytes=next,None=>break}
        }
    }
    best
}


fn scalar_digits(scalar:&[u8;32])->[u8;256] {
    let digits=unpacked_scalar_digits(scalar);
    let steps:Vec<_>=digits.iter().enumerate().rev().filter(|(_,d)|**d!=0).collect();
    assert!(!steps.is_empty() && steps.len()<=127);
    let mut plan=[0u8;256];plan[0]=steps.len()as u8;
    plan[1]=steps.last().unwrap().0 as u8;plan[2]=*steps[0].1;
    let mut pos=3;
    for i in 1..steps.len() {plan[pos]=(steps[i-1].0-steps[i].0)as u8;plan[pos+1]=*steps[i].1;pos+=2;}
    plan
}


fn a<T>(value:&T)->*mut c_void{(value as *const T).cast_mut().cast()}

const DEFAULT_STREAMS:usize=6;
const CURVE_BLOCK:usize=128;
const SCALAR_BLOCK:usize=128;
const COMPACT_PASSES:u32=6;
const ENCODING_BLOCK:usize=128;
const ROOT_TREE_BYTES:usize=131072*2*10*4;
const ROOT_INVERSE_BYTES:usize=131072/ENCODING_BLOCK*10*4;
const BUFFER_BYTES:usize=47317592-131072*65+ROOT_TREE_BYTES+ROOT_INVERSE_BYTES;
struct Pending{lane:usize,batch:usize,k:u32}
pub struct Gpu{
    context:Handle,module:Handle,kernels:[Handle;8],buffers:[u64;10],
    scalar:[u8;32],pk:[u8;32],digits:[u8;256],prefix_len:u32,has_beat:u32,
    pub device_name:String,local:usize,curve_local:usize,scalar_local:usize,
    stream:Handle,host_result:Handle,owns_context:bool,
    lanes:Vec<Gpu>,pending:VecDeque<Pending>,next_base:u64,streams:usize,
}
impl Gpu{
    pub fn new(seed:&[u8;32])->Result<Self,String>{Self::new_with_streams(seed,DEFAULT_STREAMS)}
    pub fn new_with_streams(seed:&[u8;32],streams:usize)->Result<Self,String>{
        if !(1..=8).contains(&streams){return Err("GPU streams must be 1..8".into())}unsafe{
        check(cuInit(0),"initialize")?;let mut dev=0;check(cuDeviceGet(&mut dev,0),"device")?;
        let mut name=[0u8;256];check(cuDeviceGetName(name.as_mut_ptr().cast(),256,dev),"name")?;
        let device_name=String::from_utf8_lossy(&name[..name.iter().position(|&x|x==0).unwrap_or(256)]).into_owned();
        let mut context=ptr::null_mut();check(cuCtxCreate_v2(&mut context,0,dev),"context")?;
        let mut module=ptr::null_mut();check(cuModuleLoadData(&mut module,include_bytes!("kernel.cubin").as_ptr().cast()),"load fixed SM86 kernel")?;
        let names=["vrf_init_curves","vrf_curve_attempt","vrf_curve_fallback","vrf_scalar_projective","vrf_tree_build","vrf_tree_invert","vrf_tree_finish","vrf_job_sha_init"];
        let mut kernels=[ptr::null_mut();8];
        for(i,name)in names.iter().enumerate(){check(cuModuleGetFunction(&mut kernels[i],module,cstr(name).as_ptr()),"function")?;}
        let mut gpu=Self::allocate(context,module,kernels,device_name,seed,true)?;
        gpu.streams=streams;
        for _ in 1..streams{gpu.lanes.push(Self::allocate(context,module,kernels,gpu.device_name.clone(),seed,false)?);}
        Ok(gpu)
    }}
    unsafe fn allocate(context:Handle,module:Handle,kernels:[Handle;8],device_name:String,seed:&[u8;32],owns_context:bool)->Result<Self,String>{
        let sizes=[512,80,0,131072*31*4,131072*41*4,131072*4,131072*4,8,ROOT_TREE_BYTES,ROOT_INVERSE_BYTES];let mut buffers=[0;10];
        for(i,size)in sizes.iter().enumerate(){if *size!=0{check(cuMemAlloc_v2(&mut buffers[i],*size),"buffer")?;}}
        let mut scalar:[u8;32]=Sha512::digest(seed)[..32].try_into().unwrap();scalar[0]&=248;scalar[31]&=127;scalar[31]|=64;
        let pk=*proxima_vrf::Prover::from_seed(seed).public_key();let digits=scalar_digits(&scalar);
        let mut stream=ptr::null_mut();check(cuStreamCreate(&mut stream,1),"stream")?;
        let mut host_result=ptr::null_mut();check(cuMemHostAlloc(&mut host_result,80,0),"pinned result")?;
        Ok(Self{context,module,kernels,buffers,scalar,pk,digits,prefix_len:0,has_beat:0,device_name,local:ENCODING_BLOCK,curve_local:CURVE_BLOCK,scalar_local:SCALAR_BLOCK,stream,host_result,owns_context,lanes:Vec::new(),pending:VecDeque::new(),next_base:0,streams:1})
    }
    fn lane(&self,index:usize)->&Self{if index==0{self}else{&self.lanes[index-1]}}
    /// Drain old work before job buffers are modified; old results are discarded.
    fn clear_pending(&mut self)->Result<u64,String>{
        let mut attempts=0;while let Some(p)=self.pending.pop_front(){unsafe{self.lane(p.lane).collect()?;}attempts+=p.batch as u64;}Ok(attempts)
    }
    /// Complete already-launched ranges once before a host-side job change.
    /// The caller attributes these attempts to the old immutable job.
    pub fn drain_pending(&mut self)->Result<u64,String>{self.clear_pending()}
    pub fn set_seed(&mut self,seed:&[u8;32]){
        self.clear_pending().expect("drain previous public benchmark fixture");
        self.scalar.copy_from_slice(&Sha512::digest(seed)[..32]);self.scalar[0]&=248;self.scalar[31]&=127;self.scalar[31]|=64;
        self.pk=*proxima_vrf::Prover::from_seed(seed).public_key();self.digits=scalar_digits(&self.scalar);
        for lane in &mut self.lanes{lane.set_seed(seed);}
    }
    pub fn set_job(&mut self,prefix:&[u8],beat:Option<&[u8;64]>)->Result<(),String>{
        if prefix.len()!=37{return Err("prefix must be 37 bytes".into())}
        self.clear_pending()?;self.upload_job(prefix,beat)?;
        for lane in &mut self.lanes{lane.upload_job(prefix,beat)?;}Ok(())
    }
    fn upload_job(&mut self,prefix:&[u8],beat:Option<&[u8;64]>)->Result<(),String>{
        let mut data=Vec::with_capacity(421);data.extend_from_slice(&self.scalar);data.extend_from_slice(&self.pk);data.extend_from_slice(prefix);data.extend_from_slice(&self.digits);data.extend_from_slice(beat.unwrap_or(&[0;64]));
        self.prefix_len=37;self.has_beat=beat.is_some()as u32;
        unsafe{
            check(cuMemcpyHtoD_v2(self.buffers[0],data.as_ptr().cast(),data.len()),"job upload")?;
            // Only public key + prefix enter the SHA midstate. All pending old
            // work was drained by set_job before any job buffer is changed.
            self.launch(7,1,1,0,&mut[a(&self.buffers[0])])?;
            check(cuStreamSynchronize(self.stream),"job SHA preparation")
        }
    }
    unsafe fn launch(&self,kernel:usize,count:usize,block:usize,shared:usize,args:&mut[*mut c_void])->Result<(),String>{
        check(cuLaunchKernel(self.kernels[kernel],count.div_ceil(block)as u32,1,1,block as u32,1,1,shared as u32,self.stream,args.as_mut_ptr(),ptr::null_mut()),"launch")
    }
    unsafe fn compute(&self,output:u64,base:u64,batch:usize,target:Option<u32>)->Result<(),String>{
        if !(1..=131072).contains(&batch){return Err("batch must be 1..131072".into())}let count=batch as u32;
        let[job,result,_outputs,points,curves,i0,i1,counts,tree,inverses]=self.buffers;let indices=[i0,i1];
        self.launch(0,batch,128,0,&mut[a(&curves),a(&i0),a(&counts),a(&count)])?;
        for counter in 0u32..COMPACT_PASSES{
            let slot=counter%2;let next=1-slot;check(cuMemsetD32Async(counts+u64::from(next)*4,0,1,self.stream),"clear count")?;
            self.launch(1,batch,self.curve_local,0,&mut[a(&job),a(&curves),a(&indices[slot as usize]),a(&indices[next as usize]),a(&counts),a(&base),a(&self.prefix_len),a(&count),a(&counter),a(&slot)])?;
        }
        let slot=COMPACT_PASSES%2;let start=COMPACT_PASSES;
        self.launch(2,batch,self.curve_local,0,&mut[a(&job),a(&curves),a(&indices[slot as usize]),a(&counts),a(&base),a(&self.prefix_len),a(&count),a(&slot),a(&start)])?;
        
        self.launch(3,batch,self.scalar_local,0,&mut[a(&job),a(&curves),a(&points),a(&self.prefix_len),a(&count)])?;
        self.launch(4,batch,self.local,self.local*2*10*4,&mut[a(&points),a(&tree),a(&inverses),a(&count)])?;
        let roots=count.div_ceil(self.local as u32);
        self.launch(5,roots as usize,32,0,&mut[a(&inverses),a(&roots)])?;
        let k=target.unwrap_or(0);let filter=target.is_some()as u32;
        self.launch(6,batch,self.local,self.local*2*10*4,&mut[a(&points),a(&output),a(&tree),a(&inverses),a(&count),a(&result),a(&base),a(&k),a(&self.has_beat),a(&job),a(&self.prefix_len),a(&filter)])?;Ok(())
    }

    unsafe fn submit(&self,base:u64,batch:usize,k:u32)->Result<(),String>{
        check(cuMemsetD32Async(self.buffers[1],0,20,self.stream),"reset result")?;
        // Mining filters in registers; only verification allocates full digests.
        self.compute(0,base,batch,Some(k))?;
        check(cuMemcpyDtoHAsync_v2(self.host_result,self.buffers[1],80,self.stream),"async result read")
    }
    unsafe fn collect(&self)->Result<Option<(u64,[u8;64])>,String>{
        check(cuStreamSynchronize(self.stream),"stream synchronize")?;
        let bytes=std::slice::from_raw_parts(self.host_result.cast::<u8>(),80);
        if u32::from_ne_bytes(bytes[76..80].try_into().unwrap())!=0{return Err("TAI counter exhausted".into())}
        if bytes[..4]==[0;4]{return Ok(None)}
        let nonce=u64::from(u32::from_ne_bytes(bytes[4..8].try_into().unwrap()))|u64::from(u32::from_ne_bytes(bytes[8..12].try_into().unwrap()))<<32;
        Ok(Some((nonce,bytes[12..76].try_into().unwrap())))
    }
    /// Reports one completed batch per call. Other streams remain in flight.
    /// The first base seeds disjoint ranges; job changes reset all ranges.
    pub fn search_batch(&mut self,base:u64,batch:usize,k:u32)->Result<Option<(u64,[u8;64])>,String>{unsafe{
        if !(1..=131072).contains(&batch){return Err("batch must be 1..131072".into())}
        if self.pending.front().map_or(false,|p|p.batch!=batch||p.k!=k){self.clear_pending()?;}
        if self.pending.is_empty(){
            self.next_base=base;for lane in 0..self.streams{
                self.lane(lane).submit(self.next_base,batch,k)?;self.pending.push_back(Pending{lane,batch,k});self.next_base=self.next_base.wrapping_add(batch as u64);
            }
        }
        let p=self.pending.pop_front().unwrap();let hit=self.lane(p.lane).collect()?;
        self.lane(p.lane).submit(self.next_base,batch,k)?;self.next_base=self.next_base.wrapping_add(batch as u64);self.pending.push_back(p);Ok(hit)
    }}
    pub fn verify_outputs(&mut self,base:u64,batch:usize)->Result<Vec<u8>,String>{
        self.clear_pending()?;unsafe{
            let mut buf=0;check(cuMemAlloc_v2(&mut buf,batch*65),"verification buffer")?;
            let r=(||{self.compute(buf,base,batch,None)?;check(cuStreamSynchronize(self.stream),"verification sync")?;
                let mut bytes=vec![0;batch*65];check(cuMemcpyDtoH_v2(bytes.as_mut_ptr().cast(),buf,bytes.len()),"verification read")?;Ok(bytes)})();cuMemFree_v2(buf);r
        }
    }
    pub fn explicit_buffer_bytes(&self)->usize{BUFFER_BYTES*self.streams}
    /// Independently exercise each stream's own buffers with an easy target.
    pub fn verify_stream_hits(&mut self,base:u64,batch:usize,k:u32)->Result<Vec<Option<(u64,[u8;64])>>,String>{
        self.clear_pending()?;let mut hits=Vec::new();unsafe{
            for lane in 0..self.streams{self.lane(lane).submit(base,batch,k)?;hits.push(self.lane(lane).collect()?);}
        }Ok(hits)
    }
    pub fn benchmark(&mut self,seconds:f64,batch:usize)->Result<(u64,f64),String>{
        let mut base=0u64;let warm=Instant::now();while warm.elapsed().as_secs_f64()<3.0{if self.search_batch(base,batch,513)?.is_some(){return Err("impossible warmup hit".into())}base=base.wrapping_add(batch as u64);}
        self.clear_pending()?;let start=Instant::now();let mut attempts=0u64;
        while start.elapsed().as_secs_f64()<seconds{if self.search_batch(base,batch,513)?.is_some(){return Err("impossible target hit".into())}base=base.wrapping_add(batch as u64);attempts+=batch as u64;}
        attempts+=self.clear_pending()?;Ok((attempts,start.elapsed().as_secs_f64()))
    }
}
impl Drop for Gpu{fn drop(&mut self){unsafe{
    // Child streams and buffers must be destroyed before their shared context.
    self.lanes.clear();cuStreamSynchronize(self.stream);for b in self.buffers{if b!=0{cuMemFree_v2(b);}}cuMemFreeHost(self.host_result);cuStreamDestroy_v2(self.stream);
    if self.owns_context{cuModuleUnload(self.module);cuCtxDestroy_v2(self.context);}
}}}

#[cfg(test)]
mod schedule_tests {
    use super::*;
    use curve25519_dalek::scalar::Scalar;
    fn signed(v:u8)->Scalar{let v=v as i8;if v<0{-Scalar::from(-(v as i16)as u64)}else{Scalar::from(v as u64)}}
    #[test]
    fn packed_plan_preserves_eight_times_scalar_mod_order() {
        for fixture in 0..256 {
            let digest=Sha512::digest(format!("proxima public scalar schedule invariant {fixture}").as_bytes());
            let mut scalar:[u8;32]=digest[..32].try_into().unwrap();scalar[0]&=248;scalar[31]&=127;scalar[31]|=64;
            let plan=scalar_digits(&scalar);let n=plan[0]as usize;
            assert!((1..=127).contains(&n));
            let mut value=signed(plan[2]);
            for op in 1..n {for _ in 0..plan[2*op+1]{value+=value;}value+=signed(plan[2*op+2]);}
            for _ in 0..plan[1]{value+=value;}
            assert_eq!(value,Scalar::from_bytes_mod_order(scalar)*Scalar::from(8u64));
        }
    }
}
