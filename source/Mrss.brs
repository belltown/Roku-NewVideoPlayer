'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'*********************************************************************

'
' http://www.rssboard.org/media-rss
' Parse the MRSS extensions imediately subordinate to the <channel> element.
' Only MRSS Optional Elements may appear outside <item> tags.
'
' This code may seem unnecessarily tricky. It's the result of trying
' to stick as close to the MRSS spec as possible in that there are
' many 'optional items' that may be subordinate to the <channel>,
' <item>, <media:group> and/or <media:content> elements. Lower-level
' elements 'inherit' the optional items from their ancestors.
'
Function parseMrssFeedXml (xml As Object) As Object

    ' Only optional elements are permitted outside the <item> elements
    feed = parseMrssHeader (xml)

    ' Parse all <item> elements
    feed.itemList = []
    For Each item in xml.GetNamedElementsCI ("item")
        feed.itemList.Push (parseMrssItem (item))
    End For

    Return feed

End Function

'
' MRSS optional elements may appear under the RSS <channel> element, outside of any <item> elements
'
Function parseMrssHeader (xml As Object) As Object

    header = {}

    header = parseMrssOptionalElements (xml)

    Return header

End Function

'
' An MRSS <item> element may contain <media:group>, <media:content>, and optional elements.
'
' Returns:
'   item.options is the set of MRSS optional elements immediately under the <item> element.
'   item.mediaContentList is a list of, hopefully, Roku-compatible video streams.
'   item.duration is the content's duration obtained from the media:content attributes.
'   item.fullHD will be True if any media content is in full HD (height > 720 pixels).
'   item.streamFormat will either be "mp4" or "hls" depending on the type of video streams found.
'
Function parseMrssItem (xml As Object) As Object

    item = {}

    ' First, parse any optional elements.
    ' These optionals act as defaults for any subordinate media group and media content items.
    ' If we find any Roku-compatible video streams, then we'll use the first stream's optional elements
    ' instead of the item's default optional elements.
    item.optionals = parseMrssOptionalElements (xml)
    item.mediaContentList = []
    item.duration = 0
    item.fullHD = False
    item.streamFormat = ""

    mediaGroupList = []

    ' Parse the "default" media group. This isn't actually a <media:group>, but the set of <media:content> items outside all media groups,
    ' but use the same code to handle this case
    mediaGroupList.Push (parseMrssMediaGroup (xml, item.optionals))

    ' Parse "<media:group>" elements
    For Each mediaGroupXml In xml.GetNamedElementsCI ("media:group")
        mediaGroupList.Push (parseMrssMediaGroup (mediaGroupXml, item.optionals))
    End For

    ' Combine all media content items from all groups into a single list
    mediaContentCombined = []
    For Each mediaGroup In mediaGroupList
        mediaContentCombined.Append (mediaGroup.mediaContentList)
    End For

    ' Pick out streams most likely to be Roku-compatible
    streamList = []

    ' "video/mp4" is the preferred MIME type for Roku video content
    ' Allow multiple streams as different bitrates may be specified for mp4 content
    For Each mediaContent In mediaContentCombined
        If mediaContent.typ = "video/mp4"
            streamList.Push (mediaContent)
            item.streamFormat = "mp4"
        End If
    End For

    ' Look for ".mp4" urls if the MIME type is not video/mp4
    ' Allow multiple streams as different bitrates may be specified for mp4 content
    If streamList.Count () = 0
        For Each mediaContent In mediaContentCombined
            If LCase (Right (mediaContent.url, 4)) = ".mp4"
                streamList.Push (mediaContent)
                item.streamFormat = "mp4"
            End If
        End For
    End If

    ' Look for HLS urls if no mp4 streams found.
    ' Note that a Roku content item with a StreamFormat of "hls" can only have one Stream,
    ' as it is the HLS manifest that specifies different bitrates.
    If streamList.Count () = 0
        For Each mediaContent In mediaContentCombined
            If mediaContent.typ = "application/x-mpegurl" Or mediaContent.typ = "application/vnd.apple.mpegurl" Or LCase (Right (mediaContent.url, 5)) = ".m3u8"
                streamList.Push (mediaContent)
                item.streamFormat = "hls"
                Exit For
            End If
        End For
    End If

    ' If no "video/mp4" content, look for general "video" media, and add the first such stream
    If streamList.Count () = 0
        For Each mediaContent In mediaContentCombined
            If mediaContent.medium = "video"
                streamList.Push (mediaContent)
                item.streamFormat = "mp4"
                Exit For
            End If
        End For
    End If

    ' Otherwise, add the first "unknown" stream as a catchall
    If streamList.Count () = 0
        For Each mediaContent In mediaContentCombined
            streamList.Push (mediaContent)
            item.streamFormat = "mp4"
            Exit For
        End For
    End If

    ' Return a media content list containing Roku-compatible stream attributes
    For Each mediaStream In streamList
        stream = {}
        stream.url          = mediaStream.url
        stream.quality      = mediaStream.height > 480
        stream.bitrate      = mediaStream.bitrate
        stream.contentId    = ""
        If mediaStream.height > 720
            item.fullHD = True
        End If
        If item.duration = 0
            item.duration = mediaStream.duration
        End If
        item.mediaContentList.Push (stream)
    End For

    ' If we found at least one media stream, use the optional elements from the first stream;
    ' otherwise, use the item's optional elements
    If streamList.Count () > 0
        item.optionals = streamList [0].optionals
    End If

    Return item

End Function

'
' An MRSS <media:group> element may only contain <media:content> and optional elements
'
Function parseMrssMediaGroup (xml As Object, itemOptionals As Object) As Object

    mediaGroup = {}

    mediaGroup.optionals = {}

    ' Get the optional elements specified for this media group
    groupOptionals = parseMrssOptionalElements (xml)

    ' If a particular optional element has been defined for this media group item then use it;
    ' otherwise, use the enclosing <item>'s optional element as a default value.
    ' TODO: Think of a better was to do this.
    For Each opt In groupOptionals
        ' If option is a string, copy directly
        If _isString (groupOptionals [opt])
            If groupOptionals [opt] <> ""
                ' Use media group's optional item if one exists
                mediaGroup.optionals [opt] = groupOptionals [opt]
            Else
                ' Otherwise, use item's optional item
                mediaGroup.optionals [opt] = itemOptionals [opt]
            End If
        ' If optional is an array, create new empty array and copy each array item
        Else If _isArray (groupOptionals [opt])
            mediaGroup.optionals [opt] = []
            If groupOptionals [opt].Count () > 0
                ' Use media group's optional item if one exists
                For Each item In groupOptionals [opt]
                    mediaGroup.optionals [opt].Push (item)
                End For
            Else
                ' Otherwise, use group's optional item
                For Each item In itemOptionals [opt]
                    mediaGroup.optionals [opt].Push (item)
                End For
            End If
        ' Otherwise, programming error: we currently only have strings and arrays as optionals
        Else
            uiFatalError ("parseMrssMediaGroup", LINE_NUM, "Invalid key type for optional element: " + opt)
        End If
    End For

    ' Get all media:content elements for this media group, using this group's optional elements as defaults
    mediaGroup.mediaContentList = []
    For Each mediaContentXml In xml.GetNamedElementsCI ("media:content")
        mediaGroup.mediaContentList.Push (parseMrssMediaContent (mediaContentXml, mediaGroup.optionals))
    End For

    Return mediaGroup

End Function

'
' An MRSS <media:content> element contains details for a single media item, and may contain optional elements
'
Function parseMrssMediaContent (xml As Object, groupOptionals As Object) As Object

    mediaContent = {}

    ' url="http://www.foo.com/movie.mov"
    ' fileSize="12216320"
    ' type="video/mp4"
    ' medium="video"
    ' isDefault="true"
    ' expression="full"
    ' bitrate="128" (kilobits/sec)
    ' framerate="25"
    ' samplingrate="44.1"
    ' channels="2"
    ' duration="185" (secs)
    ' height="200"
    ' width="300"
    ' lang="en"

    mediaContent.url            = _getXmlAttrString (xml, "url")
    mediaContent.typ            = LCase (_getXmlAttrString (xml, "type"))
    mediaContent.medium         = LCase (_getXmlAttrString (xml, "medium"))
    mediaContent.bitrate        = _getXmlAttrInteger (xml, "bitrate")
    mediaContent.duration       = formatMrssDuration (_getXmlAttrString (xml, "duration"))
    mediaContent.height         = _getXmlAttrInteger (xml, "height")

    ' A <media:content> element may have nested optional elements
    ' that override any enclosing <media:group> or <item> elements

    ' Start with an empty set of optional elements for this content item
    mediaContent.optionals      = {}

    ' Get the optional elements specified for this <media:content> element
    contentOptionals            = parseMrssOptionalElements (xml)

    ' If a particular optional element has been defined for this content item then use it;
    ' otherwise, use the enclosing group's optional element as a default value.
    ' TODO: Think of a better was to do this.
    For Each opt In contentOptionals
        ' If option is a string, copy directly
        If _isString (contentOptionals [opt])
            If contentOptionals [opt] <> ""
                ' Use media content's optional item if one exists
                mediaContent.optionals [opt] = contentOptionals [opt]
            Else
                ' Otherwise, use group's optional item
                mediaContent.optionals [opt] = groupOptionals [opt]
            End If
        ' If optional is an array, create new empty array and copy each array item
        Else If _isArray (contentOptionals [opt])
            mediaContent.optionals [opt] = []
            If contentOptionals [opt].Count () > 0
                ' Use media content's optional item if one exists
                For Each item In contentOptionals [opt]
                    mediaContent.optionals [opt].Push (item)
                End For
            Else
                ' Otherwise, use group's optional item
                For Each item In groupOptionals [opt]
                    mediaContent.optionals [opt].Push (item)
                End For
            End If
        ' Otherwise, programming error: we currently only have strings and arrays as optionals
        Else
            uiFatalError ("parseMrssMediaContent", LINE_NUM, "Invalid key type for optional element: " + opt)
        End If
    End For

    Return mediaContent

End Function

'
' MRSS optional elements may be subordinate to either a <channel>, <item>, <media:group>, or <media:content> element
'
Function parseMrssOptionalElements (xml As Object) As Object

    optionals = {}

    ' media:adult
    ' media:rating          - Rating
    ' media:title           - Title
    ' media:description     - Description
    ' media:keywords        - Categories (genres)
    ' media:thumbnail       - SDImageUrl/HDImageUrl
    ' media:category
    ' media:hash
    ' media:player
    ' media:credit          - Director/Actors
    '   [Use separate 'director' string and 'actors' array]
    ' media:copyright
    ' media:text
    ' media:restriction
    ' media:community
    ' media:comments
    ' media:embed
    ' media:responses
    ' media:backLinks
    ' media:status
    ' media:price
    ' media:license
    ' media:subTitle        - ShortDescriptionLine2
    ' media:peerLink
    ' media:rights
    ' media:scenes

    ' MRSS media ratings may contain a scheme attribute, e.g. "urn:simple" (adult/nonadult),
    ' or "urn:vchip" (TV-G, TV-PG, TV-14, etc.)
    ' Combine all urn:vchip ratings (and any "adult" rating) into a single rating string.
    optionals.rating = ""
    ratingList = []
    For Each ratingItem In xml.GetNamedElementsCI ("media:rating")
        scheme = LCase (_getXmlAttrString (ratingItem, "scheme"))
        ratingText = ratingItem.GetText ().Trim ()
        If scheme = "urn:v-chip" Or ratingText = "adult"
            ratingList.Push (ratingText)
        End If
    End For
    If ratingList.Count () > 0
        ' First rating
        optionals.rating = ratingList [0]
        ' Subsequent ratings each have a preceding space
        For i = 1 To ratingList.Count () - 1
            optionals.rating = optionals.rating + " " + ratingList [i]
        End For
    End If

    optionals.title = _getXmlString (xml, "media:title")

    optionals.description = _getXmlString (xml, "media:description")

    ' MRSS media keywords are a comma-delimited set of words and phrases.
    ' Generate a list of keywords/phrases.
    optionals.keywordsList = []
    keywordsString = _getXmlString (xml, "media:keywords")
    keywordTokenList = keywordsString.Tokenize (",")
    For Each keywordToken In keywordTokenList
        optionals.keywordsList.Push (keywordToken.Trim ())
    End For

    ' MRSS media thumbnails are listed in order of importance. Pick the first one
    optionals.thumbnailUrl = ""
    thumbnailList = xml.GetNamedElementsCI ("media:thumbnail")
    If thumbnailList.Count () > 0
        optionals.thumbnailUrl = _getXmlAttrString (thumbnailList [0], "url")
    End If

    ' There may be multiple MRSS media credits for each role.
    ' Roku supports only one Director, so use the first "director", "producer", or
    ' "editor" (in order of importance) as the Director.
    ' TODO: May need to tweak this code depending on how a particular RSS feed uses these elements
    optionals.director = ""
    creditList = xml.GetNamedElementsCI ("media:credit")
    If optionals.director = ""
        For Each credit In creditList
            name = credit.GetText ().Trim ()
            role = LCase (_getXmlAttrString (credit, "role"))
            If role = "director" Then optionals.director = name
        End For
    End If
    If optionals.director = ""
        For Each credit In creditList
            name = credit.GetText ().Trim ()
            role = LCase (_getXmlAttrString (credit, "role"))
            If role = "producer" Then optionals.director = name
        End For
    End If
    If optionals.director = ""
        For Each credit In creditList
            name = credit.GetText ().Trim ()
            role = LCase (_getXmlAttrString (credit, "role"))
            If role = "editor" Then optionals.director = name
        End For
    End If
    REM If optionals.director = ""
        REM For Each credit In creditList
            REM name = credit.GetText ().Trim ()
            REM role = LCase (_getXmlAttrString (credit, "role"))
            REM If role = "author" Then optionals.director = name
        REM End For
    REM End If

    ' Roku supports multiple Actors.
    ' Use any credits with a role other than "director", "producer", "editor", and "author".
    optionals.actorsList = []
    For Each credit In creditList
        name = credit.GetText ().Trim ()
        role = LCase (_getXmlAttrString (credit, "role"))
        If role <> "director" And role <> "producer" And role <> "editor" And role <> "author"
            optionals.actorsList.Push (name)
        End If
    End For

    optionals.subTitle = _getXmlString (xml, "media:subTitle")

    Return optionals

End Function

'
' Convert an MRSS duration ("h:mm:ss") to an integer in seconds
' Note, according to the MRSS specification, the duration is expressed an integer number of seconds;
' however, some RSS feeds use an mm:ss string.
' Assume, if no colons, that the duration is in seconds, otherwise h:mm:ss or mm:ss
'
Function formatMrssDuration (duration As String) As Integer
    seconds = 0
    hh = 0 : mm = 0 : ss = 0
    list = duration.Tokenize (":")
    If list.Count () = 1
        seconds = duration.ToInt ()
    Else
        If list.Count () >= 3 Then hh = list.RemoveHead ().ToInt ()
        If list.Count () >= 2 Then mm = List.RemoveHead ().ToInt ()
        If list.Count () >= 1 Then ss = list.RemoveHead ().ToInt ()
        seconds = ((hh * 60) + mm) * 60 + ss
    End If
    Return seconds
End Function
