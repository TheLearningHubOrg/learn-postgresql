/**
 * The Learning Hub - PostgreSQL 16+ DBA & Systems Architecture Roadmap
 */

export const POSTGRESQL_STAGES = [
  {
    stageNumber: 1,
    title: "Relational Foundations & SQL Engine Architecture",
    domainFocus: "Parser, rewriter, query planner/optimizer, executor, and buffer pool",
    completed: true,
    keyTopics: ["Query Lifecycle", "EXPLAIN ANALYZE", "Buffer Pool (shared_buffers)", "Execution Nodes"]
  },
  {
    stageNumber: 2,
    title: "Storage Engine, Page Layout & Tuple Headers",
    domainFocus: "8KB block layout, page headers, ItemId array, tuple headers (xmin, xmax, ctid)",
    completed: true,
    keyTopics: ["8KB Page Anatomy", "Tuple Storage", "TOAST Tables", "Free Space Map (FSM)"]
  },
  {
    stageNumber: 3,
    title: "MVCC Internals, Snapshots & Vacuuming",
    domainFocus: "Multi-Version Concurrency Control, transaction ID wraparound, autovacuum tuning",
    completed: true,
    keyTopics: ["Snapshot Isolation", "XID Wraparound (2B limit)", "HOT Updates", "Autovacuum Optimization"]
  },
  {
    stageNumber: 4,
    title: "Indexing Strategies & Access Methods",
    domainFocus: "B-Tree, BRIN, GIN, GiST, Bloom filters, and partial/expression indexes",
    completed: true,
    keyTopics: ["B-Tree Deduplication", "BRIN for Time-Series", "GIN for JSONB/Full-Text", "Covering Indexes (INCLUDE)"]
  },
  {
    stageNumber: 5,
    title: "Write-Ahead Logging (WAL) & Crash Recovery",
    domainFocus: "ARIES recovery algorithm, checkpointing, LSN (Log Sequence Number), full page writes",
    completed: true,
    keyTopics: ["WAL Buffers", "Checkpointer Tuning", "LSN Tracking", "Point-in-Time Recovery (PITR)"]
  },
  {
    stageNumber: 6,
    title: "Replication, High Availability & Connection Pooling",
    domainFocus: "Physical streaming replication, logical replication, PgBouncer, patroni consensus",
    completed: true,
    keyTopics: ["Streaming Replication", "Logical Decoding", "PgBouncer Transaction Pooling", "Patroni HA"]
  },
  {
    stageNumber: 7,
    title: "Staff PostgreSQL DBA Interview Handbook",
    domainFocus: "Catastrophic index bloat mitigation, subtransaction overflow, lock tree analysis",
    completed: true,
    keyTopics: ["Subtransaction Lock Contention", "pg_stat_statements", "Deadlock Resolution", "Zero-Downtime Schema Migrations"]
  }
];

export function getCompletedCount() {
  return POSTGRESQL_STAGES.filter(s => s.completed).length;
}

export function getProgressPercentage() {
  return Math.round((getCompletedCount() / POSTGRESQL_STAGES.length) * 100);
}
