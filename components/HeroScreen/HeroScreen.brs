' ********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

' Called when the HeroScreen component is initialized
sub Init()
  'Uncomment the print statements to see where and when the functions are called
  print "HeroScreen.brs - [init]"

  'Get references to child nodes
  m.RowList       =   m.top.findNode("RowList")
  m.background    =   m.top.findNode("Background")

  'Create a task node to fetch the UI content and populate the screen
  m.UriHandler = CreateObject("roSGNode", "UriHandler")
  m.UriHandler.observeField("content", "onContentChanged")

  makeRequest("https://iptv.streamotor.com/roku.xml?cmd=getSettings&AccountID=6th-Grade-Alabama")
  makeRequest("https://iptv.streamotor.com/roku.xml?cmd=getCategories&AccountID=6th-Grade-Alabama&CategoryID=")
	
  'Create observer events for when content is loaded
  m.top.observeField("visible", "onVisibleChange")
  m.top.observeField("focusedChild", "OnFocusedChildChange")
end sub

' Issues a URL request to the UriHandler component
sub makeRequest( URL as String )
    
	context = createObject("roSGNode", "Node")

	context.addFields({
		parameters: { uri: URL },
		num: 0,
		response: {}
	})

	'when this is set, it will launch if msg.getField() = "request" section in UriHandler.brs
	m.UriHandler.request = {
		context: context
		parser: "SMParser"
	}
  
end sub

' observer function to handle when content loads
sub onContentChanged()
  print "HeroScreen.brs - [onContentChanged]"
  m.top.numBadRequests = m.UriHandler.numBadRequests
  m.top.content = m.UriHandler.content
end sub

' handler of focused item in RowList
sub OnItemFocused()
  print "HeroScreen.brs - [onItemFocused]"
  itemFocused = m.top.itemFocused

  'When an item gains the key focus, set to a 2-element array,
  'where element 0 contains the index of the focused row,
  'and element 1 contains the index of the focused item in that row.
  if itemFocused.Count() = 2 then
    focusedContent            = m.top.content.getChild(itemFocused[0]).getChild(itemFocused[1])
    if focusedContent <> invalid then
      m.top.focusedContent    = focusedContent
      m.background.uri        = focusedContent.hdBackgroundImageUrl
    end if
  end if
end sub

' sets proper focus to RowList in case channel returns from Details Screen
sub onVisibleChange()
  print "HeroScreen.brs - [onVisibleChange]"
  if m.top.visible then m.rowList.setFocus(true)
end sub

' set proper focus to RowList in case if return from Details Screen
Sub onFocusedChildChange()
  print "HeroScreen.brs - [onFocusedChildChange]"
  if m.top.isInFocusChain() and not m.rowList.hasFocus() then m.rowList.setFocus(true)
End Sub
