package recon;

import java.io.PrintStream;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.Iterator;
import java.util.Map;

import rr.meta.AccessInfo;
//import acme.util.Assert;

/**
 * Must be used in a single thread (until merge time).
 * @author bpw
 *
 */
public class Graph implements Iterable<Graph.Edge> {
	
	protected final SparseTable<AccessInfo,Integer,Node> nodeLookupTable = new SparseTable<AccessInfo,Integer,Node>() {
		@Override
		protected Node defaultValue(AccessInfo access, Integer context) {
			return new Node(access, context);
		}
	};
	
	/**
	 * Add an edge from the source to the sink.
	 * 
	 * @param sourceAccess
	 * @param sourceContext
	 * @param sourceTime
	 * @param sinkAccess
	 * @param sinkContext
	 * @param sinkTime
	 */
	public void insert(final AccessInfo sourceAccess, final int sourceContext, final long sourceTime, final AccessInfo sinkAccess, final int sinkContext, final long sinkTime) {
//		Debug.debugf("emptygraphs", "insert %s %d %d -> %s %d %d", sourceAccess, sourceContext, sourceTime, sinkAccess, sinkContext, sinkTime);
		final Node source = nodeLookupTable.getWithDefault(sourceAccess, sourceContext);
		final Node sink = nodeLookupTable.getWithDefault(sinkAccess, sinkContext);
//		Assert.assertTrue(source != null);
//		Assert.assertTrue(sink != null);
		source.addEdgeTo(sink);
		source.stamp(sourceTime);
		sink.stamp(sinkTime);
	}
	
	/**
	 * Merge the contents of another graph into this one.
	 * @param remote
	 */
	public synchronized void publish(final Graph remote) {
//		Debug.debug("emptygraphs", "publish");
		// added node -> equivalent existing node
		final IdentityHashMap<Node,Node> remoteToLocal = new IdentityHashMap<Node,Node>();
		
		for (Node remoteSource : remote.nodeLookupTable) {
//			Debug.debug("emptygraphs", "node");
//			Assert.assertTrue(remoteSource != null);
			if (this.nodeLookupTable.contains(remoteSource.access, remoteSource.context)) {
//				Assert.assertTrue(this.nodeLookupTable.get(remoteSource.access, remoteSource.context) != null);
//				Debug.debugf("emptygraphs", "Local verion of remote node %s exists", remoteSource);
				remoteToLocal.put(remoteSource, this.nodeLookupTable.get(remoteSource.access, remoteSource.context));
			} else {
//				Debug.debugf("emptygraphs", "No local verion of remote node %s", remoteSource);
				remoteToLocal.put(remoteSource, remoteSource);
				this.nodeLookupTable.put(remoteSource.access, remoteSource.context, remoteSource);
			}
		}
		
		for (Map.Entry<Node, Node> e : remoteToLocal.entrySet()) {
			final Node remoteNode = e.getKey();
			final Node localNode = e.getValue();
			if (localNode == remoteNode) {
				// node was added from remote.
				// rewrite its out edges.
				final HashSet<Node> rewrittenEdges = new HashSet<Node>();
				for (Node sink : localNode.outEdges) {
					Node newSink = remoteToLocal.get(sink);
					if (newSink != null) {
						rewrittenEdges.add(newSink);
					} else {
						rewrittenEdges.add(sink);
					}
				}
				localNode.outEdges = rewrittenEdges;
			} else {
				// node existed in local.
				// add rewritten out edges of corresponding node in remote.
				for (Node remoteSink : remoteNode.outEdges) {
//					Assert.assertTrue(remoteToLocal.containsKey(remoteSink));
					localNode.outEdges.add(remoteToLocal.get(remoteSink));
					if (remoteNode.timestamp > localNode.timestamp) {
						localNode.timestamp = remoteNode.timestamp;
					}
				}
			}
		}
	}
	
	public int numNodes() {
		return nodeLookupTable.size();
	}
	
	public int numEdges() {
		int size = 0;
		for (Node n : nodeLookupTable) {
			size += n.numOutEdges();
		}
		return size;
	}

	static class Node {
		protected final AccessInfo access;
		protected final int context;
		protected long timestamp = 0;
		private HashSet<Node> outEdges = new HashSet<Node>();
		
		public Node(final AccessInfo access, final int context) {
//			Assert.assertTrue(access != null, "null AccessInfo given to Node constructor");
			this.access = access;
			this.context = context;
		}
		
		public void addEdgeTo(Node sink) {
//			Assert.assertTrue(sink.access != null, "null AccessInfo given to addEdgeTo");
			outEdges.add(sink);
		}
		
//		@Override
//		public int hashCode() {
//			return System.identityHashCode(this);
//		}
//		
		public void stamp(final long time) {
			this.timestamp = time;
		}
		
		public int numOutEdges() {
			return outEdges.size();
		}
		
		@Override
		public String toString() {
			return access + " " + Context.toString(context);
		}

	}
	
	static class Edge {
		public final Node source, sink;
		public Edge(final Node source, final Node sink) {
//			Assert.assertTrue(source != null, "null source given to Edge constructor");
//			Assert.assertTrue(sink != null, "null sink given to Edge constructor");
			this.source = source;
			this.sink = sink;
		}
	}
	
	public Iterator<Edge> iterator() {
		return new Iterator<Edge>() {
			private final Iterator<Node> sources = nodeLookupTable.iterator();
			private Node currentSource = null;
			private Iterator<Node> sinks = null;

			@Override
			public boolean hasNext() {
				if (sinks != null && sinks.hasNext()) {
					return true;
				}
				while (sources.hasNext()) {
					currentSource = sources.next();
					sinks = currentSource.outEdges.iterator();
					if (sinks.hasNext()) {
						return true;
					}
				}
				return false;
			}

			@Override
			public Edge next() {
				return new Edge(currentSource, sinks.next());
			}

			@Override
			public void remove() {
				throw new UnsupportedOperationException();
			}
		};
	}

	public synchronized void dump(PrintStream graphOut, boolean timestamps, boolean sourceLoc) {
                //{ "t2e0": { "src": { "I": "4197327", "C": 28, "T": "8905665823624906" }, "sink": { "I": "4197212", "C": 0, "T": "8905665825633031" } } }
		for (Edge e : this) {

                        graphOut.printf("{ \"edge\": { \"src\": { \"I\": \"%x\", \"C\": %d", e.source.access.getId(), e.source.context);
                        if(timestamps){

                        	graphOut.printf(", \"T\": \"%d\" },", e.source.timestamp);

                        }else{

                        	graphOut.printf(" },");

                        }
                        
                        graphOut.printf(" \"sink\": { \"I\": \"%x\", \"C\": %d", e.sink.access.getId(), e.sink.context);
                        if(timestamps){

                        	graphOut.printf(", \"T\": \"%d\" },", e.sink.timestamp);

                        }else{

                        	graphOut.printf(" },");

                        }

			
			if (sourceLoc) {

				graphOut.printf(" \"srcinfo\": { \"id\" : %x, \"code\" : \"" + e.source.access.getLoc() + "\"}, ",e.source.access.getId());
			}


			if (sourceLoc) {

				graphOut.printf(" \"sinkinfo\": { \"id\" : %x, \"code\" : \"" + e.source.access.getLoc() + "\"} ",e.source.access.getId());
			}

                        graphOut.printf(" } }");

			graphOut.println();
		}
	}
}
