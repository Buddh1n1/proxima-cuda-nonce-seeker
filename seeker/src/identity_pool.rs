//! Local key selection for immutable, public-key-bound mining jobs.
use proxima_vrf::Prover;
use serde::Deserialize;
use std::collections::{HashMap, HashSet};
use std::path::Path;
use std::sync::Arc;

pub struct MiningIdentity {
    /// Validated public manifest position; single-key seekers use index zero.
    pub index: usize,
    pub seed: [u8;32],
    pub prover: Prover,
}
pub struct IdentityPool {
    identities: HashMap<[u8;32],Arc<MiningIdentity>>,
    first: Arc<MiningIdentity>,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Manifest {
    version: u32,
    scheme: String,
    source_kind: String,
    source_public_key: String,
    #[serde(default)]
    branch_pair: u32,
    miners: Vec<Entry>,
    sequencers: Vec<serde_json::Value>,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Entry {
    index: usize,
    path: String,
    key_file: String,
    public_key: String,
    holder_id: String,
    weight: u32,
    #[serde(default)]
    sequencer_index: usize,
    #[serde(default)]
    chain_id: String,
}
impl IdentityPool {
    pub fn single(seed:[u8;32])->Self {
        let id=Arc::new(MiningIdentity{index:0,seed,prover:Prover::from_seed(&seed)});
        let mut identities=HashMap::new();identities.insert(*id.prover.public_key(),id.clone());
        Self{identities,first:id}
    }
    pub fn len(&self)->usize {self.identities.len()}
    pub fn first(&self)->Arc<MiningIdentity> {self.first.clone()}
    pub fn select(&self,public_hex:&str)->Result<Arc<MiningIdentity>,String> {
        let bytes=hex::decode(public_hex).map_err(|_|"job public key is not valid hex")?;
        let pk:[u8;32]=bytes.try_into().map_err(|_|"job public key must be 32 bytes")?;
        self.identities.get(&pk).cloned().ok_or_else(||"job public key is not in the local mining identity pool".into())
    }
    pub fn load(path:&Path)->Result<Self,String> {
        Self::load_with(path,super::key::load_seed)
    }
    fn load_with<F>(path:&Path,mut seed_loader:F)->Result<Self,String>
    where F: FnMut(&Path)->Result<[u8;32],String> {
        let raw=std::fs::read(path).map_err(|e|format!("cannot read public identity manifest: {e}"))?;
        if raw.len()>1024*1024{return Err("identity manifest exceeds 1 MiB".into())}
        let m:Manifest=serde_json::from_slice(&raw).map_err(|e|format!("invalid public identity manifest: {e}"))?;
        if m.version!=1||m.scheme!="slip-0010-ed25519"||m.source_kind!="ed25519-seed" {return Err("unsupported identity manifest".into())}
        if m.branch_pair>(1u32<<30)-1 {return Err("branch pair exceeds the hardened child index range".into())}
        if hex::decode(&m.source_public_key).map_or(true,|b|b.len()!=32) {return Err("invalid source public key".into())}
        if m.miners.is_empty()||m.miners.len()>32||m.miners.len()!=m.sequencers.len() {return Err("identity counts must match and be 1..32".into())}
        let parent=path.parent().unwrap_or_else(||Path::new("."));
        let mut files=HashSet::new();let mut identities=HashMap::new();let mut first=None;
        for (index,entry) in m.miners.iter().enumerate() {
            if entry.index!=index||entry.path!=format!("m/{}'/{index}'",2*m.branch_pair)||entry.weight==0||entry.weight>1000||entry.sequencer_index>=m.sequencers.len()||!entry.chain_id.is_empty() {return Err("invalid mining identity metadata".into())}
            let leaf=&entry.key_file;
            if leaf.is_empty()||leaf=="."||leaf==".."||leaf.contains(|c|matches!(c,'/'|'\\'|':'))||!files.insert(leaf.to_lowercase()) {return Err("invalid or duplicate mining key filename".into())}
            let public=hex::decode(&entry.public_key).map_err(|_|"invalid mining public key")?;
            if public.len()!=32||entry.public_key!=entry.public_key.to_lowercase()||hex::decode(&entry.holder_id).map_or(true,|b|b.len()!=32) {return Err("invalid public identity binding".into())}
            let seed=seed_loader(&parent.join(leaf)).map_err(|e|format!("cannot load mining identity {index}: {e}"))?;
            let id=Arc::new(MiningIdentity{index:entry.index,seed,prover:Prover::from_seed(&seed)});
            if id.prover.public_key().as_slice()!=public {return Err(format!("mining identity {index} public key mismatch"))}
            if identities.insert(*id.prover.public_key(),id.clone()).is_some() {return Err("duplicate mining public key".into())}
            if first.is_none(){first=Some(id)}
        }
        Ok(Self{identities,first:first.unwrap()})
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture(entries:usize)->(std::path::PathBuf,Vec<[u8;32]>) {
        let dir=std::env::temp_dir().join(format!("public-identity-fixture-{}-{}",std::process::id(),rand::random::<u64>()));std::fs::create_dir(&dir).unwrap();
        let seeds:Vec<_>=(0..entries).map(|i|{let mut s=[0u8;32];s[0]=(i+1)as u8;s}).collect();
        let miners:Vec<_>=seeds.iter().enumerate().map(|(i,s)|serde_json::json!({"index":i,"path":format!("m/0'/{i}'"),"key_file":format!("miner-{i:02}.key"),"public_key":hex::encode(Prover::from_seed(s).public_key()),"holder_id":"00".repeat(32),"weight":1,"sequencer_index":i})).collect();
        let path=dir.join("identities.json");std::fs::write(&path,serde_json::to_vec(&serde_json::json!({"version":1,"scheme":"slip-0010-ed25519","source_kind":"ed25519-seed","source_public_key":"00".repeat(32),"miners":miners,"sequencers":vec![serde_json::json!({});entries]})).unwrap()).unwrap();(path,seeds)
    }
    #[test]
    fn pool_loads_only_miners_and_selects_job_specific_prover() {
        let(path,seeds)=fixture(8);let mut opened=Vec::new();
        let pool=IdentityPool::load_with(&path,|p|{opened.push(p.file_name().unwrap().to_str().unwrap().to_owned());let i:usize=p.file_stem().unwrap().to_str().unwrap()[6..].parse().unwrap();Ok(seeds[i])}).unwrap();
        assert_eq!(opened.len(),8);assert_eq!(pool.len(),8);
        for (index,seed) in seeds.iter().enumerate(){let reference=Prover::from_seed(seed);let id=pool.select(&hex::encode(reference.public_key())).unwrap();assert_eq!(id.index,index);assert_eq!(id.prover.output(b"public job fixture").0,reference.output(b"public job fixture").0)}
        assert!(pool.select(&"00".repeat(32)).is_err());std::fs::remove_file(&path).unwrap();std::fs::remove_dir(path.parent().unwrap()).unwrap();
    }
    #[test]
    fn rejects_key_mismatch_and_escaping_keyfile_before_loading() {
        let(path,_)=fixture(1);assert!(IdentityPool::load_with(&path,|_|Ok([99;32])).is_err());
        let mut data:serde_json::Value=serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();data["miners"][0]["key_file"]=serde_json::json!("../master.key");std::fs::write(&path,serde_json::to_vec(&data).unwrap()).unwrap();
        let mut opened=false;assert!(IdentityPool::load_with(&path,|_|{opened=true;Ok([0;32])}).is_err());assert!(!opened);
        std::fs::remove_file(&path).unwrap();std::fs::remove_dir(path.parent().unwrap()).unwrap();
    }
    #[test]
    fn accepts_fresh_branch_pair_and_rejects_path_mismatch_or_overflow_before_key_reads() {
        let(path,seeds)=fixture(8);
        let mut data:serde_json::Value=serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
        data["branch_pair"]=serde_json::json!(1);
        for i in 0..8 {data["miners"][i]["path"]=serde_json::json!(format!("m/2'/{i}'"));}
        std::fs::write(&path,serde_json::to_vec(&data).unwrap()).unwrap();
        let pool=IdentityPool::load_with(&path,|p|{let i:usize=p.file_stem().unwrap().to_str().unwrap()[6..].parse().unwrap();Ok(seeds[i])}).unwrap();
        assert_eq!(pool.len(),8);
        data["miners"][0]["path"]=serde_json::json!("m/0'/0'");
        std::fs::write(&path,serde_json::to_vec(&data).unwrap()).unwrap();
        let mut opened=false;assert!(IdentityPool::load_with(&path,|_|{opened=true;Ok([0;32])}).is_err());assert!(!opened);
        data["miners"][0]["path"]=serde_json::json!("m/2'/0'");data["branch_pair"]=serde_json::json!(1u32<<30);
        std::fs::write(&path,serde_json::to_vec(&data).unwrap()).unwrap();
        assert!(IdentityPool::load_with(&path,|_|{opened=true;Ok([0;32])}).is_err());assert!(!opened);
        std::fs::remove_file(&path).unwrap();std::fs::remove_dir(path.parent().unwrap()).unwrap();
    }
}
