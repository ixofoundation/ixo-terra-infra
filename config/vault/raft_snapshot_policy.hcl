# vault-raft-snapshot CronJob. Read here returns a full snapshot; keep this the only path.
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
