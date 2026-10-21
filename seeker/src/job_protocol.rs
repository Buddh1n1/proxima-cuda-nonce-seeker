//! Host-side v1.0.2 job lifecycle. No accelerator or key-file access.
use crate::client::JobWire;
use std::sync::{atomic::{AtomicBool, Ordering}, Mutex, RwLock};
use std::time::{Duration, Instant};

pub type Beat=Option<[u8;64]>;
pub const MAX_TTL_MS:i64=120_000; // private +6 at10.24s/slot fits; malformed leases must stay bounded.
pub struct JobControl {
    pub beat:RwLock<Beat>,
    deadline:Mutex<Instant>,
    retired:AtomicBool,
}
pub fn parse_beat(text:&str)->Result<Beat,String>{
    if text.is_empty(){return Ok(None)}
    let bytes=hex::decode(text).map_err(|_|"invalid beat hex".to_string())?;
    Ok(Some(<[u8;64]>::try_from(bytes.as_slice()).map_err(|_|"beat is not64 bytes".to_string())?))
}
pub fn validate_wire(w:&JobWire)->Result<Vec<u8>,String>{
    if w.id==0{return Err("no active job".into())}
    if w.k>512{return Err("K exceeds the512-bit output".into())}
    if w.ttl_ms<=0||w.ttl_ms>MAX_TTL_MS{return Err("job TTL must be1..120000ms".into())}
    if w.slot>u32::MAX as u64{return Err("slot exceeds uint32".into())}
    let prefix=hex::decode(&w.alpha_prefix).map_err(|_|"invalid alpha_prefix hex".to_string())?;
    if prefix.len()!=37{return Err("alpha_prefix must be37 bytes".into())}
    if prefix[33..]!=(w.slot as u32).to_be_bytes(){return Err("slot differs from the VRF alpha_prefix".into())}
    if !w.pred.is_empty(){
        let pred=hex::decode(&w.pred).map_err(|_|"invalid predecessor hex".to_string())?;
        if pred.len()!=33||pred!=prefix[..33]{return Err("predecessor differs from the VRF alpha_prefix".into())}
    }
    parse_beat(&w.beat)?;
    Ok(prefix)
}
impl JobControl {
    pub fn new(w:&JobWire)->Result<Self,String>{
        validate_wire(w)?;
        Ok(Self{beat:RwLock::new(parse_beat(&w.beat)?),deadline:Mutex::new(Instant::now()+Duration::from_millis(w.ttl_ms as u64)),retired:AtomicBool::new(false)})
    }
    pub fn deadline(&self)->Instant{*self.deadline.lock().unwrap()}
    pub fn active(&self)->bool{!self.retired.load(Ordering::Relaxed)&&Instant::now()<self.deadline()}
    pub fn retire(&self){self.retired.store(true,Ordering::Relaxed);}
    pub fn tighten(&self,value:Beat){
        if let Some(value)=value {let mut beat=self.beat.write().unwrap();if beat.map_or(true,|old|value<old){*beat=Some(value)}}
    }
    pub fn accepts(&self,beta:&[u8;64])->bool{self.active()&&self.beat.read().unwrap().map_or(true,|beat|*beta<beat)}
    pub fn refresh(&self,w:&JobWire)->Result<(),String>{
        validate_wire(w)?;
        self.tighten(parse_beat(&w.beat)?);
        // Polling or a longer advertised TTL must never resurrect/extend an old lease.
        let observed=Instant::now()+Duration::from_millis(w.ttl_ms as u64);
        let mut deadline=self.deadline.lock().unwrap();*deadline=(*deadline).min(observed);
        Ok(())
    }
}
