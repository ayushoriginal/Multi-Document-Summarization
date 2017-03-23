package edu.umich.clair;

import java.io.*;
import java.net.*;

/**
 * Java client to access a MEAD server.  All you really need to do is
 * instantiate a MEADClient object, set any particular policy options that
 * can be treated as writing your meadrc file, then simply call the Exchange
 * method to go grab your summary.
 * <p>Also see my <a href="http://tangra.si.umich.edu/clair/intranet/nutchmead">
 * internal documentation</a>.
 *
 * @author	Jin Yi
 * @version	1.0
 */
public class MEADClient {
	/* member variables */
	protected String host = "localhost";
	protected int port = 6969;

	private Socket meadSock = null;
	private PrintWriter meadOut = null;
	private BufferedReader meadIn = null;

	/**
	 * This MEADopts class is like your meadrc file.  The only particular thing
	 * is that you have to instantiate a String under feature for every feature
	 * you expect you include.
	 */
	public static class MEADopts {
		public String basis = "sentences";
		public String compression = "percent";
		public int compressionAmt = 20;
		public String system = "";
		public String classifier = "";
		public String reranker = "";
		public String[] feature = null;
		public String queryterms = "";
	    public String output_mode = ""; // choices are summary, extract, centroid, but don't output one by default
	}

	public static MEADopts Policy = new MEADopts();

	/* constructors */
	public MEADClient() { }
	/**
	 * Construct this MEADClient with a specified host.
	 *
	 * @param h	the hostname
	 */
	public MEADClient(String h) { this(); host = h; }
	/**
	 * Construct this MEADClient with a specified port.
	 *
	 * @param p	the port number
	 */
	public MEADClient(int p) { this(); port = p; }
	/**
	 * Construct this MEADClient with a specified host and port.
	 *
	 * @param h	the hostname
	 * @param p	the port number
	 */
	public MEADClient(String h, int p) { this(); host = h; port = p; }


	/**
	 * Perform the client-server exchange to get a summary from a set of
	 * documents.  Aside from setting your policy options and possibly
	 * a constructor, this is the only method you should be calling.
	 *
	 * @param files	the original documents as an array of strings
	 * @return	your summary as a string
	 */
	public String Exchange(String[] files) {
		String sum = "";
		try {
			Connect();
			Send(files);
			sum = Recv();
			Disconnect();
		} catch (UnknownHostException u) {
			sum = "unknown host";
		} catch (IOException e) {
			sum = "io problem";
		}
		return sum;
	}

	/**
	 * Perform the client-server exchange to get a summary for a single
	 * document.  Aside from setting your policy options and possibly
	 * a constructor, this is the only method you should be calling.
	 *
	 * @param files	the original documents as an array of strings
	 * @return	your summary as a string
	 */
	public String Exchange(String file) {
		String sum = "";
		try {
			Connect();
			Send(file);
			sum = Recv();
			Disconnect();
		} catch (UnknownHostException u) {
			sum = "uknown host";
		} catch (IOException e) {
			sum = "io problem";
		}
		return sum;
	}

	/* Send methods */

	private void Send(String[] files) throws IOException {
		meadOut.println("<REQUEST>");
		//System.out.println("<REQUEST>");
		SendPolicy();
		for (int i=0; i < files.length; i++) {
			meadOut.println("<DOCUMENT>");
			meadOut.println(files[i]);
			meadOut.println("</DOCUMENT>");
			//System.out.println("<DOCUMENT>");
			//System.out.println(files[i]);
			//System.out.println("</DOCUMENT>");
		}
		meadOut.println("</REQUEST>");
		//System.out.println("</REQUEST>");
	}

	private void Send(String file) throws IOException {
		meadOut.println("<REQUEST>");
		//System.out.println("<REQUEST>");
		SendPolicy();
		meadOut.println("<DOCUMENT>");
		meadOut.println(file);
		meadOut.println("</DOCUMENT>");
		meadOut.println("</REQUEST>");
		//System.out.println("<DOCUMENT>");
		//System.out.println(file);
		//System.out.println("</DOCUMENT>");
		//System.out.println("</REQUEST>");
	}

	private void SendPolicy() throws IOException {
		meadOut.println("<POLICY>");
		meadOut.println("compression_basis\t" + Policy.basis);
		meadOut.println("compression_" + Policy.compression + "\t" + Policy.compressionAmt);
		//System.out.println("<POLICY>");
		//System.out.println("compression_basis\t" + Policy.basis);
		//System.out.println("compression_" + Policy.compression + "\t" + Policy.compressionAmt);
		if (!Policy.system.equals("")) {
			meadOut.println("system\t" + Policy.system);
			//System.out.println("system\t" + Policy.system);
		}
		if (!Policy.output_mode.equals("")) {
			meadOut.println("output_mode\t" + Policy.output_mode);
			//System.out.println("output_mode\t" + Policy.output_mode);
		}
		if (!Policy.classifier.equals("")) {
			meadOut.println("classifier " + Policy.classifier);
			//System.out.println("classifier " + Policy.classifier);
		}
		if (!Policy.reranker.equals("")) {
			meadOut.println("reranker " + Policy.reranker);
			//System.out.println("reranker " + Policy.reranker);
		}
		if (Policy.feature != null) {
			for (int i=0; i < Policy.feature.length; i++) {
				meadOut.println("feature " + Policy.feature[i]);
				//System.out.println("feature " + Policy.feature[i]);
			}
		}
		if (!Policy.queryterms.equals("")) {
			meadOut.println("<NUTCHQ>");
			meadOut.println("<QUERY>");
			meadOut.println("<TITLE>"+Policy.queryterms+"</TITLE>");
			meadOut.println("<NARRATIVE>"+Policy.queryterms+"</NARRATIVE>");
			meadOut.println("<DESCRIPTION>"+Policy.queryterms+"</DESCRIPTION>");
			meadOut.println("</QUERY>");
			meadOut.println("</NUTCHQ>");
			//System.out.println("<NUTCHQ>");
			//System.out.println("<QUERY>");
			//System.out.println("<TITLE>"+Policy.queryterms+"</TITLE>");
			//System.out.println("<NARRATIVE>"+Policy.queryterms+"</NARRATIVE>");
			//System.out.println("<DESCRIPTION>"+Policy.queryterms+"</DESCRIPTION>");
			//System.out.println("</QUERY>");
			//System.out.println("</NUTCHQ>");
		}
		meadOut.println("</POLICY>");
		//System.out.println("</POLICY>");
	}

	/* Recv method */
	private String Recv() throws IOException {
		boolean inSummary = false;
		String temp, sum = "";

		while ((temp = meadIn.readLine()) != null) {
			//System.out.println(temp);
			if (temp.equals("<SUMMARY>")) inSummary = true;
			else if (temp.equals("</SUMMARY>")) {
				inSummary = false;
				break;
			}
			else if (inSummary) sum += temp + "\n";
		}

		return sum;
	}

	/* Connect method */
	private void Connect() throws IOException, UnknownHostException {
		meadSock = new Socket(host, port);
		meadOut = new PrintWriter(meadSock.getOutputStream(), true);
		meadIn = new BufferedReader(
						new InputStreamReader(meadSock.getInputStream()));
	}

	/* Disconnect method */
	private void Disconnect() {
		try {
			meadOut.close();
			meadIn.close();
			meadSock.close();
		} catch (IOException e) {}
	}

	/* looks for keys in a string array */
	private int argSearch(String[] a, String key) {
		for (int i=0; i < a.length; i++) {
			if (key.compareTo(a[i]) == 0) return i;
		}
		return -10;
	}
}
