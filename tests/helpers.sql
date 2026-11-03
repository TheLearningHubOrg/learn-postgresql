-- helpers.sql
-- Assertion helpers loaded before every test file in the same psql session.
-- They live in pg_temp, so they vanish when the session ends.

-- Fails unless actual equals expected. NULL = NULL counts as equal.
CREATE FUNCTION pg_temp.assert_eq(actual anycompatible, expected anycompatible, label text)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF actual IS DISTINCT FROM expected THEN
    RAISE EXCEPTION 'FAIL %: expected %, got %', label, expected, actual;
  END IF;
  RAISE NOTICE 'ok   %', label;
END
$$;

-- Runs stmt and fails unless it raises exactly the SQLSTATE given.
-- The statement runs in a subtransaction, so its effects are rolled back.
CREATE FUNCTION pg_temp.expect_error(stmt text, expected_state text, label text)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  got text;
BEGIN
  BEGIN
    EXECUTE stmt;
  EXCEPTION WHEN OTHERS THEN
    got := SQLSTATE;
  END;
  IF got IS NULL THEN
    RAISE EXCEPTION 'FAIL %: statement succeeded, expected SQLSTATE %', label, expected_state;
  ELSIF got <> expected_state THEN
    RAISE EXCEPTION 'FAIL %: got SQLSTATE %, expected %', label, got, expected_state;
  END IF;
  RAISE NOTICE 'ok   % (SQLSTATE %)', label, got;
END
$$;
