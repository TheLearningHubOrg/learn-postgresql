-- 04_mvcc_test.sql
-- MVCC made visible: an UPDATE writes a new row version instead of
-- overwriting the old one, and a rolled-back write leaves no visible trace.

BEGIN;

CREATE TEMP TABLE mvcc_demo (id integer PRIMARY KEY, v integer) ON COMMIT DROP;
INSERT INTO mvcc_demo VALUES (1, 10);

DO $$
DECLARE
  before_ctid tid;
  after_ctid  tid;
  before_xmin xid;
  after_xmin  xid;
BEGIN
  SELECT ctid, xmin INTO before_ctid, before_xmin FROM mvcc_demo WHERE id = 1;
  UPDATE mvcc_demo SET v = 11 WHERE id = 1;
  SELECT ctid, xmin INTO after_ctid, after_xmin FROM mvcc_demo WHERE id = 1;

  ASSERT before_ctid = '(0,1)', format('first version at (0,1), got %s', before_ctid);
  ASSERT after_ctid  = '(0,2)', format('new version at (0,2), got %s', after_ctid);
  ASSERT before_xmin = after_xmin, 'both versions were written by this transaction';
  RAISE NOTICE 'ok   UPDATE created a new tuple version (% -> %)', before_ctid, after_ctid;
END
$$;

-- The old version is still on the page until VACUUM removes it, but no
-- snapshot sees it: the table shows one row.
SELECT pg_temp.assert_eq((SELECT count(*) FROM mvcc_demo), 1::bigint,
  'only the latest version is visible');

-- A savepoint is a subtransaction; rolling back to it discards its writes.
SAVEPOINT before_insert;
INSERT INTO mvcc_demo VALUES (2, 20);
ROLLBACK TO SAVEPOINT before_insert;

SELECT pg_temp.assert_eq((SELECT count(*) FROM mvcc_demo WHERE id = 2), 0::bigint,
  'rolled-back insert is invisible');

SELECT pg_temp.assert_eq(pg_current_xact_id_if_assigned() IS NOT NULL, true,
  'a transaction that wrote data has a transaction id');

ROLLBACK;
