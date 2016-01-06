'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'*********************************************************************

'
' Parse RSS <channel> element iTunes extensions, as described in:
'  http://www.apple.com/itunes/podcasts/specs.html
'
Function parseITunesFeedXml (xml As Object) As Object

    feed = parseITunesHeader (xml)

    feed.itemList = []
    For Each item in xml.GetNamedElementsCI ("item")
        feed.itemList.Push (parseITunesItem (item))
    End For

    Return feed

End Function

'
' Certain iTunes attributes are subordinate to the RSS <channel> element,
' and outside the <item> elements
'
Function parseITunesHeader (xml As Object) As Object

    header = {}

    ' <itunes:author>           - Actors
    ' <itunes:block>
    ' <itunes:category>         - Categories
    ' <itunes:image>            - SDPosterUrl/HDPosterUrl
    ' <itunes:explicit>
    ' <itunes:complete>
    ' <itunes:new-feed-url>
    ' <itunes:owner>
    ' <itunes:subtitle>         - ShortDescriptionLine2
    ' <itunes:summary>          - Description

    header.author = _getXmlString (xml, "itunes:author")

    header.categoryList = getITunesCategories (xml)

    header.image = ""
    imageList = xml.GetNamedElementsCI ("itunes:image")
    If imageList.Count () > 0
        image = imageList [0]
        header.image = _getXmlAttrString (image, "href")
    End If

    header.subtitle = _getXmlString (xml, "itunes:subtitle")

    header.summary = _getXmlString (xml, "itunes:summary")

    Return header

End Function

'
' Parse the iTunes elements that are subordinate to an <item> element
'
Function parseITunesItem (xml As Object) As Object

    item = {}

    ' <itunes:author>               - Actors
    ' <itunes:block>
    ' <itunes:image>                - SDImageUrl/HDImageUrl
    ' <itunes:duration>             - Runtime
    ' <itunes:explicit>
    ' <itunes:isClosedCaptioned>    - ClosedCaptions
    ' <itunes:order>
    ' <itunes:subtitle>             - ShortDescriptionLine2
    ' <itunes:summary>              - Description

    item.author = _getXmlString (xml, "itunes:author")

    item.image = ""
    imageList = xml.GetNamedElementsCI ("itunes:image")
    If imageList.Count () > 0
        image = imageList [0]
        item.image = _getXmlAttrString (image, "url")
    End If

    item.duration = formatITunesDuration (_getXmlString (xml, "itunes:duration"))

    item.isClosedCaptioned = LCase (_getXmlString (xml, "itunes:isClosedCaptioned")) = "yes"

    item.subtitle = _getXmlString (xml, "itunes:subtitle")

    item.summary = _getXmlString (xml, "itunes:summary")

    Return item

End Function

'
' Get category and (recursively) sub-category values
'
Function getITunesCategories (xml As Object) As Object
    categoryList = []
    For Each category In xml.GetNamedElementsCI ("itunes:category")
        categoryText = _getXmlAttrString (category, "text")
        If categoryText <> ""
            categoryList.Push (categoryText)
        End If
        categoryList.Append (getITunesCategories (category))
    End For
    Return categoryList
End Function

'
' Convert an iTunes duration ("h:mm:ss") to an integer in seconds
'
Function formatITunesDuration (duration As String) As Integer
    hh = 0 : mm = 0 : ss = 0
    list = duration.Tokenize (":")
    If list.Count () >= 3 Then hh = list.RemoveHead ().ToInt ()
    If list.Count () >= 2 Then mm = List.RemoveHead ().ToInt ()
    If list.Count () >= 1 Then ss = list.RemoveHead ().ToInt ()
    Return ((hh * 60) + mm) * 60 + ss
End Function
