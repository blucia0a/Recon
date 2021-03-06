package recon;


public class Context {
	
	public static final int EMPTY = 0, LOCAL_READ = 1, LOCAL_WRITE = 2, REMOTE_READ = 3, REMOTE_WRITE = 4;
	public static final int WIDTH = 3;

	/**
	 * You must adjust the type of the context accordingly (or just keep something bigger):
	 * SIZE <= 2:  byte
	 * SIZE <= 5:  short
	 * SIZE <= 10: int
	 * SIZE <= 21: long   
	 */
	public static final int SIZE = 5;

	public static int fresh() {
		return 0;
	}
	
	public static int push(int c, int op) {
//		Debug.debugf("ctx", "push(%s, %d) => %s", Context.toString(c), op, Context.toString((c << WIDTH) | op));
		return (c << WIDTH) | op;
	}
	
	public static String toString(int c) {
		String s = "";
		for (int i = 0; i < SIZE; i++) {
			s += ((c >> (i * WIDTH)) & ((1 << WIDTH)) - 1) + " ";
		}
		return s;
	}
}
