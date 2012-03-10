package recon;

import java.util.HashSet;
import java.util.Set;

import rr.meta.AccessInfo;
import rr.state.ShadowThread;
import rr.state.ShadowVar;

public class ReconShadow implements ShadowVar {
	protected ShadowThread lastWriter;
	protected int context;
	protected AccessInfo pc;
	protected long timestamp;
	protected final Set<ShadowThread> users = new HashSet<ShadowThread>();
	
	public final void write(final ShadowThread lastWriter, final int context, final AccessInfo pc, final long timestamp) {
		this.lastWriter = lastWriter;
		this.context = context;
		this.pc = pc;
		this.timestamp = timestamp;
	}
	
	public final void localWrite(final int context, final AccessInfo pc, final long timestamp) {
		this.context = context;
		this.pc = pc;
		this.timestamp = timestamp;
	}
	
	public final void flushUsers() {
		users.clear();
	}
}
