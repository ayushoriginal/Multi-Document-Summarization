var divrank = function() {

var data = parent.jsonfile;
var d = 0.85;
var threshold = 0.001;
// var inlinks = {};
var outlinks = {};
var sinkpages = {};
var pageranks = {};
var newPR = {};
var count = 1;
var undirected,
	nodeSize,
	nodePadding,
	chargeSize,
	linkDistanceSize,
	gravitySize;

if (data == '4conf.json') {
	undirected = false;
	nodeSize = 500;
	nodePadding = 2;
	chargeSize = -35;
	linkDistanceSize = 20;
	gravitySize = 0.1;
} else if (data == 'toy.json') {
	undirected = true;
	nodeSize = 50;
	nodePadding = 2;
	chargeSize = -30;
	linkDistanceSize = 40;
	gravitySize = 0.05;
}

var width = 600,
    height = 550;

var force = d3.layout.force()
    .charge(chargeSize)			// for variable charge, try: function(d,i) { return pageranks[d.id] * -1000; } )
    .linkDistance(linkDistanceSize)
    .gravity(gravitySize)
    .size([width, height]);

// svg = d3.select("#network").append("svg")
//     .attr("width", width)
//     .attr("height", height);

// find all pages with no outlinks
var getSinks = function (outpages) {
	return Object.keys(outpages).filter(function (e) {
		return outpages[e].length == 0; });
};

//---------------------------------------------------------
// PAGE RANK CALCULATION
// PR(i) = (1-d)/n + d (PR(j1)/D(j1) + ... + PR(jn)/D(jn))
//---------------------------------------------------------

var pageRank = function() {

	var sinkPR = 0;
	sinkpages = getSinks(outlinks);

	// get pagerank for sinks
    for (var i = 0; i < sinkpages.length; i++) {
		sinkPR += pageranks[sinkpages[i]];
    }

	for (var i = 0; i < nodes.length; i++) {
		var u = nodes[i].id;
		newPR[u] = (1 - d) / n;
		newPR[u] += d * sinkPR / n;
	}

	for (var i = 0; i < nodes.length; i++) {
		var u = nodes[i].id;
		var p_u = pageranks[u];

		var d_t = 0;
		for (var j = 0; j < outlinks[u].length; j++) {
			var v = outlinks[u][j];
			d_t += pageranks[v];
		}

		for (var j = 0; j < outlinks[u].length; j++) {
			var v = outlinks[u][j];
			newPR[v] += d * p_u * pageranks[v] / d_t;
		}

	}

	// check threshold to stop
	if (Math.abs(newPR[max] - pageranks[max]) < threshold) {
		clearInterval(timer);
		var test = 0.0;
		for (var i = 1; i <= n; i++) {
			test += pageranks[i];
		}
		console.log(test);
	} else {
		for (var i = 0; i < n; i++) {
			pageranks[nodes[i].id] = newPR[nodes[i].id];
		}
	}

};

// maps node ids to node objects and returns d3.map of nodes -> ids
var mapNodes = function(nodes) {
    var nodesMap = d3.map();
    nodes.forEach(function(n) {
        return nodesMap.set(n.id, n);
    });
    return nodesMap;
};

// make links point to node objects instead of ids
var mapLinks = function(links, nodesMap) {
    links.forEach(function(l) {
        l.source = nodesMap.get(l.source);
        l.target = nodesMap.get(l.target);
    });
};

//----------------
// MAKE THE GRAPH
//----------------

function restart() {
	var svg = d3.select("#network").append("svg")
    		.attr("width", width)
    		.attr("height", height);

	d3.json(data, function(graph) {

		nodes = graph.nodes;
		links = graph.links;
		n = nodes.length;

		// initialize the arrays for incoming and outgoing links
		for (var i = 0; i < n; i++) {
			//inlinks[nodes[i].id] = [];
			outlinks[nodes[i].id] = [];
		}

		// set starting pagerank values
		for (var i = 0; i < n; i++) {
			pageranks[nodes[i].id] = 1.0 / n;

			///// DIVRANK: ADD SELF LINKS
			//inlinks[nodes[i].id].push(nodes[i].id);
			outlinks[nodes[i].id].push(nodes[i].id);
		}

		max = nodes[0].id;

		// create arrays of incoming links to each node
		// and count number of outgoing links
		for (var i = 0; i < links.length; i++) {
			var target = links[i].target;
			var source = links[i].source;
			
			//inlinks[target].push(source);
			outlinks[source].push(target);

			if (undirected == true) {
				//inlinks[source].push(target);
				outlinks[target].push(source);
			}

			// find maximum inlinked node for threshold testing
			if (outlinks[target].length > outlinks[max].length)
				max = target;
		};

		// map ids to node objects and make links point to those objects
	    var nodesMap = mapNodes(nodes);
	    mapLinks(links, nodesMap);

		//---------------------------
		// DRAW AND REDRAW THE GRAPH
		//---------------------------

		function update() {

			force.nodes(graph.nodes)
		    	.links(graph.links)
		    	.start();

			var link = svg.selectAll("line.link")
		   		.data(graph.links);
		   	
		   	link.enter().append("line")
		   		.attr("class", "link")
		   		.style("stroke-width", "2");

		   	var node = svg.selectAll("circle.node")
				.data(graph.nodes);
		 		
		 	node.transition()
		 		.duration(900)
		 		.attr("r", function(d,i) { return pageranks[d.id] * nodeSize + nodePadding; })
		      	.select("title")
		      	.text(function(d,i) {
		      		return d.name + ": " + pageranks[d.id]; });

		 	node.enter().append("circle")
		   		.attr("class", "node")
		   		.attr("r", function(d,i) { return pageranks[d.id] * nodeSize; })
		   		.style("fill", "teal")
		   		.call(force.drag)
		   		.append("title");

		  	force.on("tick", function() {
		    	link.attr("x1", function(d) { return d.source.x; })
		        	.attr("y1", function(d) { return d.source.y; })
		        	.attr("x2", function(d) { return d.target.x; })
		        	.attr("y2", function(d) { return d.target.y; });

		   	node.attr("cx", function(d) { return d.x; })
		    	.attr("cy", function(d) { return d.y; });

		    });

		  	var iter = "Iteration: " + count;
		  	document.getElementById('iteration').innerHTML = iter;
		    count++;

		}

		// draw the graph the first time
		update();

		//-----------------------
		// TIMER FOR TRANSITIONS
		//-----------------------

		timer = setInterval(function() {
			pageRank();
			update();
			// console.log("inlinks",inlinks);
			// console.log("outlinks",outlinks);
			// console.log("sinkpages",sinkpages);
			// console.log("pageranks",pageranks);
		}, 500);

	});

};

restart();

d3.select("#order").on("change", function() {
	clearInterval(timer);
	d = this.value;
	count = 1;
	// console.log(d);
	d3.select("svg").remove();
	restart();
});

}

divrank();