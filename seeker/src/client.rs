//! Modified for this standalone CUDA distribution: persistent-job identity fields
//! and typed job/beat verdict handling. Original Apache-2.0 licensing is retained.
//! The three calls of the seeker protocol (kb/external_nonce_seeker.md),
//! over a blocking HTTP client. The seeker is the client: it dials the miner.

use serde::{Deserialize, Serialize};
use std::time::Duration;

#[derive(Deserialize, Debug, Default, Clone)]
pub struct JobWire {
    pub id: u64,
    #[serde(default)]
    pub alpha_prefix: String,
    #[serde(default)]
    pub k: u32,
    #[serde(default)]
    pub beat: String,
    #[serde(default)]
    pub ttl_ms: i64,
    #[serde(default)]
    pub pubkey: String,
    #[serde(default)]
    pub slot: u64,
    #[serde(default)]
    pub pred: String,
}

#[derive(Serialize)]
struct ResultWire<'a> {
    id: u64,
    nonce: String,
    beta: String,
    attempts: u64,
    seeker: &'a str,
}

#[derive(Serialize)]
struct ReportWire<'a> {
    id: u64,
    attempts: u64,
    seeker: &'a str,
}

#[derive(Deserialize)]
struct ErrorWire {
    #[serde(default)]
    error: String,
}

#[derive(Deserialize)]
struct VerdictWire {
    accepted: bool,
    #[serde(default)]
    beat: String,
}

/// A valid result leaves a v1.0.2 job open and returns its current target.
#[derive(Debug, PartialEq, Eq)]
pub enum Verdict {
    Accepted(Option<[u8; 64]>),
    Beaten([u8; 64]),
    /// 409: the job is over, nothing to fix.
    Stale,
    /// 422: the nonce does not solve the job as the miner sees it, a seeker bug.
    Rejected(String),
}

pub struct Client {
    agent: ureq::Agent,
    base: String,
    token: Option<String>,
}

impl Client {
    pub fn new(base: &str, token: Option<String>) -> Client {
        let agent = ureq::AgentBuilder::new()
            .timeout_connect(Duration::from_secs(5))
            // a long-poll may legitimately hold the connection for the wait
            .timeout_read(Duration::from_secs(30))
            .timeout_write(Duration::from_secs(10))
            .build();
        Client { agent, base: base.trim_end_matches('/').to_string(), token }
    }

    fn with_auth(&self, req: ureq::Request) -> ureq::Request {
        match &self.token {
            Some(t) => req.set("Authorization", &format!("Bearer {t}")),
            None => req,
        }
    }

    /// Long-polls the current job: returns when it differs from `after` or
    /// after `wait_ms`, whichever is first.
    pub fn get_job(&self, after: u64, wait_ms: u64) -> Result<JobWire, String> {
        let req = self
            .agent
            .get(&format!("{}/seeker/job", self.base))
            .timeout(Duration::from_millis(wait_ms.saturating_add(2000).min(30_000)))
            .query("after", &after.to_string())
            .query("wait", &wait_ms.to_string());
        let resp = self.with_auth(req).call().map_err(describe)?;
        resp.into_json::<JobWire>().map_err(|e| format!("job response: {e}"))
    }

    pub fn post_result(&self, id: u64, nonce: u64, beta: &[u8; 64], attempts: u64, seeker: &str) -> Result<Verdict, String> {
        let body = ResultWire { id, nonce: hex::encode(nonce.to_be_bytes()), beta: hex::encode(beta), attempts, seeker };
        let req = self.with_auth(self.agent.post(&format!("{}/seeker/result", self.base)).timeout(Duration::from_secs(2)));
        match req.send_json(&body) {
            Ok(resp) => {
                let wire = resp.into_json::<VerdictWire>().map_err(|e| format!("result response: {e}"))?;
                decode_verdict(wire)
            }
            Err(ureq::Error::Status(409, _)) => Ok(Verdict::Stale),
            Err(ureq::Error::Status(422, resp)) => {
                let reason = resp.into_json::<ErrorWire>().map(|e| e.error).unwrap_or_default();
                Ok(Verdict::Rejected(reason))
            }
            Err(e) => Err(describe(e)),
        }
    }

    pub fn post_report(&self, id: u64, attempts: u64, seeker: &str) -> Result<(), String> {
        let body = ReportWire { id, attempts, seeker };
        let req = self.with_auth(self.agent.post(&format!("{}/seeker/report", self.base)).timeout(Duration::from_secs(2)));
        req.send_json(&body).map(|_| ()).map_err(describe)
    }
}

fn decode_verdict(wire: VerdictWire) -> Result<Verdict, String> {
    let beat = if wire.beat.is_empty() { None } else {
        let bytes = hex::decode(&wire.beat).map_err(|_| "invalid result beat hex".to_string())?;
        Some(<[u8; 64]>::try_from(bytes.as_slice()).map_err(|_| "result beat is not 64 bytes".to_string())?)
    };
    if wire.accepted { Ok(Verdict::Accepted(beat)) }
    else { Ok(Verdict::Beaten(beat.ok_or("beaten result omitted its beat")?)) }
}

#[cfg(test)]
mod protocol_tests {
    use super::*;
    #[test]
    fn accepted_and_beaten_responses_keep_the_current_beat() {
        let beat = [7; 64];
        for accepted in [true, false] {
            let wire: VerdictWire = serde_json::from_value(serde_json::json!({"accepted": accepted,"beat":hex::encode(beat)})).unwrap();
            assert_eq!(decode_verdict(wire).unwrap(), if accepted {Verdict::Accepted(Some(beat))} else {Verdict::Beaten(beat)});
        }
        // Old accepted-only replies remain safe: the caller tightens to its own verified beta.
        assert_eq!(decode_verdict(serde_json::from_str(r#"{"accepted":true}"#).unwrap()).unwrap(), Verdict::Accepted(None));
        assert!(decode_verdict(serde_json::from_str(r#"{"accepted":false}"#).unwrap()).is_err());
        assert!(decode_verdict(serde_json::from_str(r#"{"accepted":true,"beat":"00"}"#).unwrap()).is_err());
        assert!(serde_json::from_str::<VerdictWire>(r#"{}"#).is_err());
    }
    #[test]
    fn result_wire_keeps_big_endian_nonce_and_public_beta() {
        let result = ResultWire {id: 17, nonce:hex::encode(0x0102030405060708u64.to_be_bytes()),beta:hex::encode([4;64]),attempts:19,seeker:"fixture"};
        let value=serde_json::to_value(result).unwrap();
        assert_eq!(value["nonce"],"0102030405060708");assert_eq!(value["beta"],hex::encode([4;64]));assert_eq!(value["attempts"],19);
    }
}

fn describe(e: ureq::Error) -> String {
    match e {
        ureq::Error::Status(code, resp) => {
            let reason = resp.into_json::<ErrorWire>().map(|e| e.error).unwrap_or_default();
            format!("HTTP {code} {reason}")
        }
        ureq::Error::Transport(t) => t.to_string(),
    }
}
