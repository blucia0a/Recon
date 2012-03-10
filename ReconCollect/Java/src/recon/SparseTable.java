package recon;

import java.util.HashMap;
import java.util.Iterator;

/**
 * A sparse table (or two-keyed map) implemented with HashMaps.
 * 
 * @author bpw
 *
 * @param <X>
 * @param <Y>
 * @param <V>
 */
public class SparseTable<X,Y,V> implements Iterable<V> {
	protected final HashMap<X,HashMap<Y,V>> table = new HashMap<X,HashMap<Y,V>>();
	
	
	/**
	 * Check whether the given cell contains a non-null value.
	 * @param x
	 * @param y
	 * @return
	 */
	public boolean contains(X x, Y y) {
		HashMap<Y,V> map = table.get(x);
		if (map == null) {
			return false;
		}
		return map.get(y) != null;
	}
	
	/**
	 * Get the contents of the given cell.
	 * @param x
	 * @param y
	 * @return
	 */
	public V get(X x, Y y) {
		HashMap<Y,V> map = table.get(x);
		if (map == null) {
			return null;
		}
		return map.get(y);
	}
	
	/**
	 * Default value creator used in getWithDefault.  Override to define custom lazy init behavior.
	 * @param x
	 * @param y
	 * @return
	 */
	protected V defaultValue(X x, Y y) {
		return null;
	}

	/**
	 * Get the contents of the given cell, returning a new default value (computed by defaultValue(x,y))
	 * if the cell is empty.
	 * @param x
	 * @param y
	 * @return
	 */
	public V getWithDefault(X x, Y y) {
		HashMap<Y,V> map = table.get(x);
		if (map == null) {
			map = new HashMap<Y,V>();
			table.put(x, map);
		}
		V v = map.get(y);
		if (v == null) {
			v = defaultValue(x, y);
			map.put(y, v);
		}
		return v;
	}

	/**
	 * Put the value v in cell (x,y).
	 * @param x
	 * @param y
	 * @param v
	 */
	public void put(X x, Y y, V v) {
		HashMap<Y,V> map = table.get(x);
		if (map == null) {
			map = new HashMap<Y,V>();
			table.put(x, map);
		}
		map.put(y, v);
	}
	
//	public V putIfAbsent(X x, Y y, V v) {
//		HashMap<Y,V> map = table.get(x);
//		if (map == null) {
//			map = new HashMap<Y,V>();
//			table.put(x, map);
//		}
//		final V old = map.get(y);
//		if (old == null) {
//			map.put(y, v);
//		}
//		return old;
//	}

	public synchronized int size() {
		int size = 0;
		for (HashMap<Y,V> row : table.values()) {
			size += row.size();
		}
		return size;
	}

	/**
	 * Iterator over non-empty cells.
	 */
	@Override
	public Iterator<V> iterator() {
		return new Iterator<V>() {
			private final Iterator<HashMap<Y,V>> rows = table.values().iterator();
			private Iterator<V> cols = null;

			@Override
			public boolean hasNext() {
				if (cols != null && cols.hasNext()) {
					return true;
				}
				while (rows.hasNext()) {
					cols = rows.next().values().iterator();
					if (cols.hasNext()) {
						return true;
					}
				}
				return false;
			}

			@Override
			public V next() {
				return cols.next();
			}

			@Override
			public void remove() {
				throw new UnsupportedOperationException();
			}
		};

	}
}
