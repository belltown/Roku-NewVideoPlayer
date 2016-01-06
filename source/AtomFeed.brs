'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'*********************************************************************

'
' https://tools.ietf.org/html/rfc4287
' https://en.wikipedia.org/wiki/Atom_%28standard%29
'
Function getAtomContent (xml As Object) As Object

    contentItem = {}

    uiSoftError ("getAtomContent", LINE_NUM, "Atom feeds are not currently supported")

    Return contentItem

End Function

Function parseAtomFeedXml (xml As Object) As Object

    feed = {}

    uiSoftError ("parseAtomFeedXml", LINE_NUM, "Atom feeds are not currently supported")

    Return feed

End Function
