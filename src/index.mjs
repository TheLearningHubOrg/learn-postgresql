import { PostgreSQLPage } from './mvcc.mjs';
import { POSTGRESQL_STAGES, getCompletedCount, getProgressPercentage } from './roadmap.mjs';

console.log('======================================================');
console.log('  The Learning Hub - PostgreSQL 16+ Architecture');
console.log('======================================================');
console.log('Engine: PostgreSQL Relational MVCC & Storage Engine');
console.log('Default Page Size: 8192 bytes (8 KB)');
console.log('Concurrency: Multi-Version Concurrency Control (MVCC)\n');

// 1. MVCC Lifecycle Demonstration
console.log('--- 1. MVCC Tuple Lifecycle & Snapshot Isolation ---');
const page = new PostgreSQLPage(0);

// Insert tuple at xid 100
page.insert('usr_1', 100, { name: 'Alice', balance: 500 });
console.log('Transaction 100: INSERT usr_1 (Alice, $500)');

// Update tuple at xid 105
page.update('usr_1', 100, 105, { name: 'Alice', balance: 750 });
console.log('Transaction 105: UPDATE usr_1 (Alice, $750) -> creates new tuple version');

// Create Snapshot: xmin=102, xmax=106, xip=[105] (Transaction 105 is still uncommitted)
const snapshotActive = { xmin: 102, xmax: 106, xip_list: [105] };
console.log('\nSnapshot S1 (while tx 105 is active):');
page.tuples.forEach((t, idx) => {
  const visible = page.isTupleVisible(t, snapshotActive);
  console.log(`  Tuple version ${idx} (xmin=${t.xmin}, xmax=${t.xmax}): visible = ${visible ? 'YES' : 'NO'}`);
});

// Snapshot after commit: tx 105 committed
const snapshotCommitted = { xmin: 106, xmax: 106, xip_list: [] };
console.log('\nSnapshot S2 (after tx 105 committed):');
page.tuples.forEach((t, idx) => {
  const visible = page.isTupleVisible(t, snapshotCommitted);
  console.log(`  Tuple version ${idx} (xmin=${t.xmin}, xmax=${t.xmax}): visible = ${visible ? 'YES' : 'NO'}`);
});

// Run VACUUM simulation with oldest active xid = 110
const reclaimed = page.vacuum(110);
console.log(`\nVACUUM Execution: reclaimed ${reclaimed} dead tuple(s). Active page tuples: ${page.tuples.length}\n`);

// 2. 7-Stage Pedagogical Roadmap
console.log('--- 2. 7-Stage PostgreSQL Masterclass Roadmap ---');
for (const stage of POSTGRESQL_STAGES) {
  const icon = stage.completed ? '[OK]' : '[..]';
  console.log(` ${icon} Stage ${stage.stageNumber}: ${stage.title}`);
  console.log(`      Focus: ${stage.domainFocus}`);
  console.log(`      Topics: ${stage.keyTopics.join(', ')}`);
}

const completed = getCompletedCount();
const percent = getProgressPercentage();
console.log('------------------------------------------------------');
console.log(`Progress: ${completed}/7 Stages Complete (${percent}%)`);
console.log('======================================================\n');
