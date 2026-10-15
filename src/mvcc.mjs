/**
 * PostgreSQL MVCC Simulator & Tuple Lifecycle Engine
 * Demonstrates t_xmin, t_xmax, snapshot visibility, and VACUUM garbage collection.
 */

export class PostgreSQLPage {
  constructor(pageNumber = 0, pageSize = 8192) {
    this.pageNumber = pageNumber;
    this.pageSize = pageSize;
    this.tuples = [];
  }

  insert(tupleId, xmin, data) {
    const tuple = {
      id: tupleId,
      xmin,
      xmax: 0,
      data,
      dead: false
    };
    this.tuples.push(tuple);
    return tuple;
  }

  update(tupleId, oldTupleXmin, updateXid, newData) {
    const oldTuple = this.tuples.find(t => t.id === tupleId && t.xmax === 0);
    if (!oldTuple) {
      throw new Error(`Tuple with id ${tupleId} not found or already deleted.`);
    }
    // Set xmax on old tuple
    oldTuple.xmax = updateXid;
    // Insert new version of tuple
    const newTuple = {
      id: tupleId,
      xmin: updateXid,
      xmax: 0,
      data: newData,
      dead: false
    };
    this.tuples.push(newTuple);
    return newTuple;
  }

  delete(tupleId, deleteXid) {
    const tuple = this.tuples.find(t => t.id === tupleId && t.xmax === 0);
    if (!tuple) {
      throw new Error(`Tuple with id ${tupleId} not found.`);
    }
    tuple.xmax = deleteXid;
    return tuple;
  }

  /**
   * Evaluates visibility of a tuple given a PostgreSQL snapshot:
   * Snapshot: { xmin: earliest active XID, xmax: first unassigned XID, xip_list: array of running XIDs }
   */
  isTupleVisible(tuple, snapshot) {
    // 1. If tuple was inserted after our snapshot started, it is invisible
    if (tuple.xmin >= snapshot.xmax) return false;

    // 2. If tuple was inserted by an active transaction when snapshot was taken, invisible
    if (snapshot.xip_list.includes(tuple.xmin)) return false;

    // 3. If tuple has not been deleted, it is visible
    if (tuple.xmax === 0) return true;

    // 4. If tuple was deleted after our snapshot started, the delete is invisible -> tuple remains visible
    if (tuple.xmax >= snapshot.xmax) return true;

    // 5. If tuple was deleted by a transaction still active when snapshot was taken, delete is invisible
    if (snapshot.xip_list.includes(tuple.xmax)) return true;

    // Tuple was deleted and committed before our snapshot -> invisible
    return false;
  }

  /**
   * Simulates VACUUM: cleans up tuples where xmax is committed and older than oldest active transaction.
   */
  vacuum(oldestActiveXid) {
    const beforeCount = this.tuples.length;
    this.tuples = this.tuples.filter(t => {
      if (t.xmax !== 0 && t.xmax < oldestActiveXid) {
        return false; // Reclaimed as dead space
      }
      return true;
    });
    return beforeCount - this.tuples.length;
  }
}
