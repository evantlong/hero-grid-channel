' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' A context node has a parameters and response field
' - parameters corresponds to everything related to an HTTP request
' - response corresponds to everything related to an HTTP response
' Component Variables:
'   m.port: the UriFetcher message port
'   m.jobsById: an AA containing a history of HTTP requests/responses

' init(): UriFetcher constructor
' Description: sets the execution function for the UriFetcher
' 						 and tells the UriFetcher to run
sub init()
  print "UriHandler.brs - [init]"

  ' create the message port
  m.port = createObject("roMessagePort")

  ' Stores the content if not all requests are ready
  m.top.ContentCache = createObject("roSGNode", "ContentNode")

  ' setting callbacks for url request and response
  m.top.observeField("request", m.port)
  m.top.observeField("ContentCache", m.port)

  ' setting the task thread function
  m.top.functionName = "go"
  m.top.control = "RUN"
end sub

'this function runs all of the handler
sub go()
	
	m.jobsById = {}

	' UriFetcher event loop
	while true
		msg = wait(0, m.port)
		mt = type(msg)
		print "Received event type '"; mt; "'"
		' If a request was made

		if mt = "roSGNodeEvent"

			if msg.getField()="request"

				'msg.getData contains the request
				if addRequest(msg.getData()) <> true then 
					print "Invalid request"
				end if	

			else if msg.getField()="ContentCache"
				'updateContent()
			else
				print "Error: unrecognized field '"; msg.getField() ; "'"
			end if	

		' If a response was received
		else if mt="roUrlEvent"
			processResponse(msg)
		else
			print "Error: unrecognized event type '"; mt ; "'"
		end if

	  end while
end sub


'make HTTP requeset
function addRequest(request as Object) as Boolean
	
	print "UriHandler.brs - [addRequest]"

	context = request.context
	parser = request.parser

	'create parser if it does not exist already
	if type(parser) = "roString"
     	if m.Parser = invalid
			m.Parser = createObject("roSGNode", parser)
			m.Parser.observeField("parsedContent", m.port)
		end if	
	end if	

	print "Parser"
	print m.Parser

	'set uri
	uri = context.parameters.uri

	'set transfer request
	urlXfer = createObject("roUrlTransfer")
	urlXfer.setUrl(uri)
	urlXfer.setPort(m.port)

	r = CreateObject("roRegex", "^https","i")
	if(r.IsMatch(uri))
		urlXfer.EnablePeerVerification(False)
	end if

	' should transfer more stuff from parameters to urlXfer
	idKey = stri(urlXfer.getIdentity()).trim()
	' AsyncGetToString returns false if the request couldn't be issued
	ok = urlXfer.AsyncGetToString()
	
	if ok then
		m.jobsById[idKey] = {
		context: request,
		xfer: urlXfer
		}
	else
		print "Error: request couldn't be issued"
	end if

end function

sub processResponse(msg as Object)
	print "UriHandler.brs - [processResponse]"

	idKey = stri(msg.GetSourceIdentity()).trim()
	job = m.jobsById[idKey]

	if job <> invalid
		context = job.context
		parameters = context.context.parameters
		jobnum = job.context.context.num
		uri = parameters.uri
		print "Response for transfer '"; idkey; "' for URI '"; uri; "'"

		result = {
			code:    msg.GetResponseCode(),
			headers: msg.GetResponseHeaders(),
			content: msg.GetString(),
			num:     jobnum
		}
		' could handle various error codes, retry, etc. here
		m.jobsById.delete(idKey)
		job.context.context.response = result

		if msg.GetResponseCode() = 200
			'get the parser type from the cmd 
			r = CreateObject("roRegex", "cmd=(\w+)","i")
			cmd = r.Match(uri)

			m.Parser.cmd = cmd[1] 
			m.Parser.response = result
		else
			print "Error: status code was: " + (msg.GetResponseCode()).toStr()
			m.top.numBadRequests++
			m.top.numRowsReceived++
		end if
	else
		print "Error: event for unknown job "; idkey
	end if

end sub
