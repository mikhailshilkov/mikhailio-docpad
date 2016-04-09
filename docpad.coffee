# The DocPad Configuration File
# It is simply a CoffeeScript Object which is parsed by CSON
cheerio = require('cheerio')
url = require('url')

docpadConfig = {

	# =================================
	# Template Data
	# These are variables that will be accessible via our templates
	# To access one of these within our templates, refer to the FAQ: https://github.com/bevry/docpad/wiki/FAQ

	templateData:

		# Specify some site properties
		site:
			# The production url of our website
			# If not set, will default to the calculated site URL (e.g. http://localhost:9778)
			url: "http://mikhail.io"

			# Here are some old site urls that you would like to redirect from
			oldUrls: [
				'mikeshilkov.workpress.com'
			]

			# The default title of our website
			title: "Mikhail Shilkov"

			# The website author's name
			author: "Mikhail Shilkov"

			# The website description (for SEO)
			description: """
				When your website appears in search results in say Google, the text here will be shown underneath your website's title.
				"""

			# The website keywords (for SEO) separated by commas
			keywords: """
				place, your, website, keywoards, here, keep, them, related, to, the, content, of, your, website
				"""

			# The website's styles
			styles: [
				'/vendor/normalize.css'
				'/vendor/h5bp.css'
				'/styles/style.css'
			]

			# The website's scripts
			scripts: [
				"""
				<!-- jQuery -->
				<script src="//ajax.googleapis.com/ajax/libs/jquery/2.1.0/jquery.min.js"></script>
				<script>window.jQuery || document.write('<script src="/vendor/jquery.js"><\\/script>')</script>
				"""

				'/vendor/log.js'
				'/vendor/modernizr.js'
				'/scripts/script.js'
			]


		# -----------------------------
		# Helper Functions

		# Get the prepared site/document title
		# Often we would like to specify particular formatting to our page's title
		# we can apply that formatting here
		getPreparedTitle: ->
			# if we have a document title, then we should use that and suffix the site's title onto it
			if @document.title
				"#{@document.title} | #{@site.title}"
			# if our document does not have it's own title, then we should just use the site's title
			else
				@site.title

		getPageUrlWithHostname: ->
			"#{@site.url}#{@document.url}"

		# Get the prepared site/document description
		getPreparedDescription: ->
			# if we have a document description, then we should use that, otherwise use the site's description
			@document.description or @site.description

		# Get the prepared site/document keywords
		getPreparedKeywords: ->
			# Merge the document keywords with the site keywords
			@site.keywords.concat(@document.keywords or []).join(', ')

		getTagUrl: (tag) ->
			tag.replace(" ", "-").replace(" ", "-").replace(".", "-").toLowerCase()

		getIdForDocument: (document) ->
			hostname = url.parse(@site.url).hostname
			date = document.date.toISOString().split('T')[0]
			path = document.url
			"tag:#{hostname},#{date},#{path}"

		fixLinks: (content, baseUrlOverride) ->
			baseUrl = @site.url
			if baseUrlOverride
				baseUrl = baseUrlOverride
			regex = /^(http|https|ftp|mailto):/

			$ = cheerio.load(content)
			$('img').each ->
				$img = $(@)
				src = $img.attr('src')
				$img.attr('src', baseUrl + src) unless regex.test(src)
			$('a').each ->
				$a = $(@)
				href = $a.attr('href')
				$a.attr('href', baseUrl + href) unless regex.test(href)
			$.html()

		getTeaser: (teaser, content) ->
			result = ""
			if teaser
				result = teaser
			else if content
				result = content.replace("&amp;#39;","'").replace("&amp;quot;",'"').replace("&#39;","'").replace("&quot;",'"').replace(/<\/?[^>]+(>|$)/g, "").substring(0, 450) 
			result

		moment: require('moment')

		getJavascriptEncodedTitle: (title) ->
			title.replace("'", "\\'")

		# Disqus.com settings
		disqusShortName: 'mikhailio'

	# =================================
	# Collections

	# Here we define our custom collections
	# What we do is we use findAllLive to find a subset of documents from the parent collection
	# creating a live collection out of it
	# A live collection is a collection that constantly stays up to date
	# You can learn more about live collections and querying via
	# http://bevry.me/queryengine/guide

	collections:

		# Create a collection called posts
		# That contains all the documents that will be going to the out path posts
		posts: ->
			@getCollection("html").findAllLive({layout: 'post', draft: $exists: false},[{date:-1}])
			#@getCollection('documents').findAllLive({relativeOutDirPath: 'posts'})
		menuPages: ->
			@getCollection("html").findAllLive({menu: $exists: true},[{menuOrder:1}])


	plugins:
                tags:
                       extension: '/index.html.eco'
                       injectDocumentHelper: (document) ->
                              document.setMeta(
                                 layout: 'page'
                                 data: """
                                   <%- @partial('tag', @) %>
                                   """
                              )
                ghpages:
                        deployRemote: 'target'
                        deployBranch: 'master'
		cleanurls:
			trailingSlashes: true

	# =================================
	# DocPad Events

	# Here we can define handlers for events that DocPad fires
	# You can find a full listing of events on the DocPad Wiki

	events:

		# Server Extend
		# Used to add our own custom routes to the server before the docpad routes are added
		serverExtend: (opts) ->
			# Extract the server from the options
			{server} = opts
			docpad = @docpad

			# As we are now running in an event,
			# ensure we are using the latest copy of the docpad configuraiton
			# and fetch our urls from it
			latestConfig = docpad.getConfig()
			oldUrls = latestConfig.templateData.site.oldUrls or []
			newUrl = latestConfig.templateData.site.url

			# Redirect any requests accessing one of our sites oldUrls to the new site url
			server.use (req,res,next) ->
				if req.headers.host in oldUrls
					res.redirect(newUrl+req.url, 301)
				else
					next()
}

# Export our DocPad Configuration
module.exports = docpadConfig