import edu.umich.clair.MEADClient;

import java.io.IOException;

/**
 * Sample MEAD summarizer client: 
 *
 * In the main method you can change the document to summarize
 * and the type of summary that will be retrieved.  A local meadd
 * must be running if you want to use the default host.  You can
 * also set the host to use if you have meadd running elsewhere.
 *
*/
public class Summarizer {
    
    private String text;
    private String query;
    private String summary;
    private double summlength;
    private MEADClient MC=null;
    private String sys=null;
    private int comp = 20;

    public Summarizer() {
	this.text=null;
	this.summary=null;
    }

    public Summarizer(String text, String summtype) throws IOException {
	this(text, summtype, "localhost");
    }

    public Summarizer(String text, String summtype, String host) throws IOException {

	this.text = text;
	this.summlength = 0;

	parseSummtype(summtype);

	if(sys == "fulldocs") {
	    summary=text;
	}
	else if(sys == "CENTROID") {
	    MC = new MEADClient(host);
	    MC.Policy.output_mode = "centroid";
	    MC.Policy.compressionAmt = comp;

	    summary = MC.Exchange(text);

	    if(summary.equals("\n") || summary.equals("")){
		summlength=0;
		summary=null;
	    }
	    else if(summary.startsWith("io problem")) {
		throw new IOException("The mead server on " + host + " is returning nothing");
	    }
	    else {
		this.summlength = summary.length();
	    }

	}
	else {
	    // get a regular summary
	    MC.Policy.output_mode = "summary";
	    MC = new MEADClient(host);
	    MC.Policy.system = sys;
	    MC.Policy.compressionAmt = comp;
	   
	    // get MEAD summary right here
	    summary = MC.Exchange(text);

	    if(summary.equals("\n") || summary.equals("")){
		summlength=0;
		summary=null;
	    }
	    else if(summary.startsWith("io problem")) {
		throw new IOException("The mead server on " + host + " is having problems summarizing");
	    }
	    else {
		this.summlength = summary.length();
	    }
	}
    }


    //needs to be rewritten
    /*
    public Summarizer(String text, String query, String summtype, String host) {
	this(text, summtype, host);
	this.query = query;
	MC.Policy.queryterms = query;
    }
    */

    private void parseSummtype(String summtype) {
	if(summtype.toUpperCase().startsWith("RAND")) {
	    sys = "RANDOM";
	}
	else if(summtype.toUpperCase().startsWith("FULLDOC")) {
	    sys = "fulldocs";
	}
	else if(summtype.toUpperCase().startsWith("LEAD")) {
	    sys = "LEADBASED";
	}
	else if(summtype.toUpperCase().startsWith("CENT")) {
	    sys = "CENTROID";
	}
	else {
	    sys = "";
	}

	if(summtype.endsWith("10")) {
	    comp = 10;
	}
	else if(summtype.endsWith("5")) {
	    comp = 5;
	}
	else {
	    comp = 20;
	}
    }


    public String getSummResults() {
	    return summary;
    }

    public double getSummLength() {
	return summlength;
    }


    public static void main(String[] args) throws Exception {
	
	// anHTMLDoc is the document that will get summarized
	// Change this hmtl document or read it in from  file if you want.  Just make sure you have periods in there
	// so that MEAD knows where the sentences are.
	String anHTMLDoc = "New York Daily News - Sports - Mike Lupica: This logic fails test.  Mike Lupica is one of the best-known and widely read sports columnists in the United States.  He began his newspaper career with the New York Post in 1975, at the age of 23, covering the Knicks. In 1977, he became the youngest columnist ever at a New York paper when he joined the Daily News.  His work has also appeared in Newsday, The National, Esquire, Sport, World Tennis, Tennis, Travel Leisure Golf, Playboy, Sports Illustrated and Parade.  Lupica has written or co-written four previous nonfiction books: \"Reggie,\" the autobiography of Reggie Jackson; \"Parcells,\" an autobiography of former Giants and Patriots coach Bill Parcells; \"Wait 'Till Next Year,\" co-written with William Goldman; and \"Shooting From The Lip,\" a collection of columns.  In addition, he has written a number of novels including \"Dead Air,\" \"Extra Credits,\" \"Limited Partner,\" \"Jump and Bump, \"Run,\" \"Full Court Press\" and the new \"Red Zone.\"  Read the new novel that Elmore Leonard calls \"Lupica's funniest,\" \"Red Zone.\"  Now you can visit our complete archive of Mike Lupica's sports columns.  Click below for the complete lineup and a free sneak preview of each column, plus info on our affordable purchase options!  Union exec Gene Orza says steroids are no worse than cigarettes.  If you are looking for the credo of the Major League Baseball Players Association, there it is.  They are right about a keeping a salary cap out of baseball, even bragging in negotiations about protecting the Yankees.  They are right about preventing Alex Rodriguez from going to the Red Sox, because they know better than Rodriguez what is good for him.  And of course they are right about steroids.  Here is Gene Orza, now officially drunk with his great power at the Major League Baseball Players Association, speaking about steroids yesterday at something called the Octagon World Congress of Sports:  \"Let's assume that steroids are a very bad thing to take,\" Orza says on his junket.  \"I have no doubt that they are not worse than cigarettes.\"  It's a double negative, but you get his meaning.  \"But I would never say to the clubs as an individual who represents the interests of the players, 'Gee, I guess by not allowing baseball to suspend and fine players for smoking cigarettes, I am not protecting their health.'\"  But here is a question for Orza, who says the rest of the world is much too hysterical about his ballplayers using steroids:  If steroids are so harmless, and not even as much of a danger as a Marlboro Light, how come he even agreed to any testing at all?  Understand something about Orza: He is one of the union children of Marvin Miller, and thinks it is still the 1960s and the baseball commissioner and the owners are out to get him, that they still want the players to work for nothing, and never be able to move from team to team.  One of these days the players are going to figure out how much Orza's big mouth harms their association more than helps it.  But for now, he is still the players' COO.  It makes him big and loud, even if he and Donald Fehr, the other union boss, gave more ground in the last collective bargaining agreement than Miller ever did in his life.  So Orza did a lot of talking yesterday, and when you read his quotes last night, it was clear that he either doesn't believe steroids are harmful, or doesn't want to believe.  But then, it doesn't really matter, does it?  In California yesterday, he cited studies that said normal dosages of androstenedione, Mark McGwire's muscle juice of choice, do not even increase muscle mass.  And yet he and Fehr, another beauty, sat in those negotiating rooms with the commissioner's men and agreed to anonymous steroid testing last year.  Which produced enough positive results that the testing is now mandatory.  Now Orza turns around and tells us they're no more than a trifle.  So he isn't just loud now, he is a public hypocrite.  \"Whether it's good or bad for you, it's a far cry to say that because it's bad for you, you should participate in a structure which allows your employer to punish you for doing something you shouldn't be doing,\" Orza says.  \"That's not my understanding of what unions do for their employees,\" Orza says.  He really thinks he is John L. Lewis, even working with A-Rod and Jeter and Manny Ramirez.  He thinks that an association with 252 million ballplayers and 190 million ballplayers and 160 million ballplayers, all free to make these huge individual deals, are steelworkers, or the Teamsters.  Like Fehr, he is desperate to get out of Marvin Miller's shadow.  So he fights for ballplayers to be able to take whatever kind of drugs they want, and makes that sound more noble than the Equal Rights Amendment.  Orza compares performance-enhancing drugs to cigarettes, even though no one can remember cigarettes ever altering the playing field in any way.  He dazzles you with footwork and this is all part of the great lie that steroids don't affect the health of his players, or the health of the game.  And if he really does believe that, he should be fired tomorrow.  By players who know better, who are tired of being lumped in with all the drug cheats of baseball.  Who ought to figure out that he works for them, not the other way around.  Already, there have to be smart players wondering how Orza helps anything by talking about cigarettes with anabolic steroids.  In the real world, not Orza's increasingly isolated world, there are real medical experts from coast to coast, ones with no agenda, who will tell you in chapter and verse why steroids given to healthy people are such a danger.  And how any respected member of the medical profession who distributes them to people without \"medical implications\" faces criminal prosecution under the Anabolic Steroid Control Act of 1990.  So apparently, it isn't just baseball fans, and the media, who think this junk is poison.  He only cares about protecting his turf and, apparently, protecting the 5 -to-7 of his membership that tested positive for steroids last season.  Somehow they're good, and the government is bad.  But one more time: If steroids aren't bad, why are his players getting tested for them?  Home News Views Sports Entertainment Business Boroughs City Life Services ";
	
	// here are some summary types
	// uncomment the one that you want to use
	String type = "P10";  // P is just a letter meaning that it isn't one of the other types
	                     // this will return a standard MEAD summary
	//String type = "LEADBASED10"; 
	//String type = "CENTROID"; 
	//String type = "RANDOM20"; 
	//String type = "fulldocs"; 

	//defaults to localhost
	Summarizer summer = new Summarizer(anHTMLDoc, type);
	//Summarizer summer = new Summarizer(anHTMLDoc, type, "meadd.elsewhere.edu");

	System.out.println(summer.getSummResults());

    }
}
