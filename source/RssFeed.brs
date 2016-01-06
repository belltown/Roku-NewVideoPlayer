'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'*********************************************************************

'
' http://www.rssboard.org/rss-specification
' https://en.wikipedia.org/wiki/RSS
'

'
' Construct a Content Item object containing Content Meta-Data fields for an RSS feed,
' including a list of Content Item objects corresponding to the feed's <item> elements.
'
Function getRssContent (xml As Object) As Object

    contentItem = {}

    ' An RSS feed should contain exactly one <channel> element.
    ' If this feed contains more than one <channel> element, only read the first one.
    ' If there are no <channel> elements, then still attempt to find <item> elements
    channelList = xml.GetNamedElementsCI ("channel")
    If channelList.Count () > 0
        channelXml = channelList [0]
    Else
        channelXml = xml
    End If

    ' Parse all standard RSS tags, MRSS extensions, and iTunes extensions
    rss = parseRssFeedXml (channelXml)
    mrss = parseMrssFeedXml (channelXml)
    iTunes = parseITunesFeedXml (channelXml)

    ' Preferred Title order is MRSS title, RSS title, iTunes subtitle
    title = mrss.title
    If title = "" Then title = rss.title
    If title = "" Then title = iTunes.subtitle

    ' Set up content item Meta-Data
    contentItem.Title = _xmlEntityDecode (_stripHtmlTags (title))
    contentItem.xxFeedContentType = "video"     ' Currently, only support video content
    contentItem.xxIsCached = True               ' The feed will now be in memory
    contentItem.xxFeedType = "items"            ' The child content items are a list of <item> elements

    ' Use a fixed-length array for storing the content item list
    contentItem.xxChildContentList = CreateObject ("roArray", rss.itemList.Count (), False)

    ' Set up each content item
    ' Limit the maximum number of <item> elements handled (0 = no limit)
    For index = 0 To rss.itemList.Count () - 1
        If index < MAX_ITEMS () Or MAX_ITEMS () = 0
            contentItem.xxChildContentList.Push (getRssItemContent (rss, mrss, iTunes, index))
        End If
    End For

    Return contentItem

End Function

'
' Construct a ContentItem object containing Content Meta-Data fields based on the result
' of parsing the RSS, MRSS, and iTunes <item> elements.
' Assign content item attributes from either RSS, MRSS, or iTunes data, the preference
' for each attribute depending on the particular attribute, and what data the feed provides
' that seems the closest match to the attribute.
'
Function getRssItemContent (rss As Object, mrss As Object, iTunes As Object, index As Integer) As Object

    contentItem = {}

    rssItem = rss.itemList [index]
    mrssItem = mrss.itemList [index]
    mrssItemOptionals = mrssItem.optionals
    iTunesItem = iTunes.itemList [index]

    title = mrssItemOptionals.title
    If title = "" Then title = rssItem.title
    If title = "" Then title = iTunesItem.subtitle
    If title = "" Then title = mrss.title
    If title = "" Then title = rss.title

    subTitle = iTunesItem.subtitle
    If subTitle = "" Then subTitle = mrssItemOptionals.subTitle

    description = iTunesItem.summary
    If description = "" Then description = iTunesItem.subtitle
    If description = "" Then description = mrssItemOptionals.description
    If description = "" Then description = rssItem.description
    If description = "" Then description = rss.description
    If description = "" Then description = mrss.description

    ' Use MRSS item's <media:thumbnail> image, if present
    sdImg = mrssItemOptionals.thumbnailUrl
    hdImg = mrssItemOptionals.thumbnailUrl

    ' Otherwise, look for MRSS root <media:thumbnail> image
    If sdImg = "" Then sdImg = mrss.thumbnailUrl
    If hdImg = "" Then hdImg = mrss.thumbnailUrl

    ' Otherwise, use <itunes:image>
    iTunesImage = iTunesItem.image
    If iTunesImage = "" Then iTunesImage = iTunes.image
    If sdImg = "" Then sdImg = iTunesImage
    If hdImg = "" Then hdImg = iTunesImage

    runtime = iTunesItem.duration
    If runtime = 0 Then runtime = mrssItem.duration

    director = mrssItemOptionals.director
    If director = "" Then director = rss.managingEditor

    actorList = []
    For Each actor In mrssItemOptionals.actorsList
        actorList.Push (actor)
    End For
    If actorList.Count () = 0
        actorList.Push (iTunesItem.author)
    End If
    If actorList.Count () = 0
        For Each actor In mrss.actorsList
            actorList.Push (actor)
        End For
    End If

    genreList = []
    For Each genre In iTunes.categoryList
        genreList.Push (genre)
    End For
    If genreList.Count () = 0
        For Each genre In rssItem.categoryList
            genreList.Push (genre)
        End For
    End If
    If genreList.Count () = 0
        For Each genre In mrssItemOptionals.keywordsList
            genreList.Push (genre)
        End For
    End If

    rating = mrssItemOptionals.rating
    If rating = "" Then rating = mrss.rating

    starRating = ""

    releaseDate = rssItem.pubDate
    If releaseDate = "" Then releaseDate = rss.pubDate

    cc = iTunesItem.isClosedCaptioned

    fullHD = mrssItem.fullHD

    ' If the device is running in SD mode, there must be at least one SD stream specified.
    ' If the content contains no SD streams, but the device is running in SD mode,
    ' then add an SD stream corresponding to the lowest bitrate HD stream,
    ' to ensure there is at least one playable stream.
    hasHD = False
    hasSD = False
    streamFormat = mrssItem.streamFormat
    streamList = mrssItem.mediaContentList
    defaultSDStream = {bitrate: 9999999}
    For Each stream In streamList
        If stream.quality = True
            hasHD = True
        Else
            hasSD = True
        End If
        If stream.bitrate < defaultSDStream.bitrate
            ' Save the stream having the lowest bitrate
            defaultSDStream = stream
            ' Make it an SD stream
            defaultSDStream.quality = False
        End If
    End For
    ' Ensure that if running in SD mode, there is at least one SD stream specified
    If Not _isHD () And hasSD = False And streamList.Count () > 0
        streamList.Push (defaultSDStream)
    End If

    ' If no MRSS <media> streams then use the RSS item's <enclosure>, <link>, or <guid>
    If streamList.Count () = 0
        url = ""
        If rssItem.enclosureUrl <> ""
            url = rssItem.enclosureUrl
        Else If rssItem.link <> ""
            url = rssItem.link
        Else If rssItem.guid <> ""
            url = rssItem.guid
        End If
        If url <> ""
            streamList.Push ({url: url, quality: False, bitrate: 0, contentid: ""})
            ' Most likely, if we get this far we won't yet have determined the streamFormat.
            ' All we have to go on is the file name.
            If streamFormat = ""
                If LCase (Right (url, 5)) = ".m3u8"
                    streamFormat = "hls"
                Else
                    streamFormat = "mp4"
                End If
            End If
        End If
    End If

    ' Make a content id out of the hash of the first stream url.
    contentId = ""
    If streamList.Count () > 0
        contentId = _hash (streamList [0].url)
    End If

    ' Set the content id for each media stream
    For Each stream In streamList
        stream.contentId = contentId
    End For

    ' Sanitize text fields
    title = _xmlEntityDecode (_stripHtmlTags (title))

    subtitle = _xmlEntityDecode (_stripHtmlTags (subtitle))

    description = _xmlEntityDecode (_stripHtmlTags (description))

    For index = 0 To genreList.Count () - 1
        genreList [index] = _xmlEntityDecode (_stripHtmlTags (genreList [index]))
    End For

    For index = 0 To actorList.Count () - 1
        actorList [index] = _xmlEntityDecode (_stripHtmlTags (actorList [index]))
    End For

    ' Set up the Content Meta-Data, only setting fields that have data, to minimize Content Item size
    contentItem.Live                    = False ' Currently no way of discerning whether an RSS feed item is "live"
    contentItem.HDBranded               = hasHD Or fullHD
    contentItem.IsHD                    = hasHD Or fullHD
    contentItem.FullHD                  = fullHD
    contentItem.ContentId               = contentId
    contentItem.Streams                 = streamList
    contentItem.ContentType             = "episode"         ' "movie" or "episode" (determines how image displayed on roSpringboardScreen)
    contentItem.StreamFormat            = streamFormat
    If cc = True                        Then contentItem.ClosedCaptions         = True
    If title <> ""                      Then contentItem.Title                  = title
    If title <> ""                      Then contentItem.ShortDescriptionLine1  = title
    If subtitle <> ""                   Then contentItem.ShortDescriptionLine2  = subtitle
    If sdImg <> ""                      Then contentItem.SDPosterUrl            = sdImg
    If hdImg <> ""                      Then contentItem.HDPosterUrl            = hdImg
    If rating <> ""                     Then contentItem.Rating                 = UCase (rating)
    If runtime > 0                      Then contentItem.Length                 = runtime
    If director <> ""                   Then contentItem.Director               = director
    If starRating <> ""                 Then contentItem.StarRating             = starRating
    If releaseDate <> ""                Then contentItem.ReleaseDate            = releaseDate
    If description <> ""                Then contentItem.Description            = description
    If genreList.Count () > 0           Then contentItem.Categories             = genreList
    If actorList.Count () > 0           Then contentItem.Actors                 = actorList

    Return contentItem

End Function

'
' Parse an RSS feed Xml document, only returning the RSS-specific feed items (MRSS/iTunes extensions)
'
Function parseRssFeedXml (xml As Object) As Object

    feed = parseRssHeader (xml)

    feed.itemList = []
    For Each item in xml.GetNamedElementsCI ("item")
        feed.itemList.Push (parseRssItem (item))
    End For

    Return feed

End Function

'
' Parse an RSS 2.0 <channel> element, as described in http://www.rssboard.org/rss-specification
' These items are common to all <item> elements.
' Only the RSS-specific <channel> elements are returned.
'
Function parseRssHeader (xml As Object) As Object

    header = {}

    ' <title>           - Title
    ' <link>
    ' <description>     - Description
    ' <language>
    ' <copyright>
    ' <managingEditor>  - Director (only if not email address)
    ' <webMaster>
    ' <pubDate>         - ReleaseDate
    ' <lastBuildDate>
    ' <category>        - Categories (genres)
    ' <generator>
    ' <docs>
    ' <cloud>
    ' <ttl>
    ' <image>           - SDPosterUrl/HDPosterUrl
    ' <rating>
    ' <textInput>
    ' <skipHours>
    ' <skipDays>

    header.title = _getXmlString (xml, "title")

    header.description = _getXmlString (xml, "description")

    ' The managingEditor element is normally an e-mail address;
    ' however, allow its use as a Director item if it is not an e-mail address
    header.managingEditor = ""
    managingEditor = _getXmlString (xml, "managingEditor")
    If Instr (1, managingEditor, "@") < 1
        header.managingEditor = managingEditor
    End if

    header.pubDate = formatPubDate (_getXmlString (xml, "pubDate"))

    header.categoryList = []
    For Each category In xml.GetNamedElementsCI ("category")
        categoryItem = category.GetText ().Trim ()
        If categoryItem <> ""
            header.categoryList.Push (categoryItem)
        End If
    End For

    header.image = _getXmlString (xml, "image")

    Return header

End Function

'
' Parse an RSS 2.0 <item> element, as described in http://www.rssboard.org/rss-specification
' These items are common to all <item> elements.
' Only the RSS-specific <item> elements are returned.
'
Function parseRssItem (xml As Object) As Object

    item = {}

    ' <title>           - Title
    ' <link>            - Streams
    ' <description>     - Description
    ' <author>
    ' <category>        - Categories (genres)
    ' <comments>
    ' <enclosure>       - Streams
    ' <guid>            - Streams
    ' <pubDate>         - ReleaseDate
    ' <source>

    item.title = _getXmlString (xml, "title")

    item.link = _getXmlString (xml, "link")

    item.description = _getXmlString (xml, "description")

    item.categoryList = []
    For Each category In xml.GetNamedElementsCI ("category")
        categoryItem = category.GetText ().Trim ()
        If categoryItem <> ""
            item.categoryList.Push (categoryItem)
        End If
    End For

    item.enclosureUrl = ""
    enclosureList = xml.GetNamedElementsCI ("enclosure")
    If enclosureList.Count () > 0
        enclosure = enclosureList [0]
        ' Assume enclosureUrl corresponds to a video MIME type
        item.enclosureUrl = _getXmlAttrString (enclosure, "url")
    End If

    ' A <guid> element may represent a link to the item
    item.guid = _getXmlString (xml, "guid")

    item.pubDate = formatPubDate (_getXmlString (xml, "pubDate"))

    Return item

End Function

'
' Format an RFC 822 or RFC 2822 RSS pubDate element (with 2 or 4-digit year) for display as a ReleaseDate Content Meta-Data Item.
' https://www.ietf.org/rfc/rfc0822.txt (specified by RSS 2.0).
' https://www.ietf.org/rfc/rfc2822.txt (specified by Apple for their iTunes podcasts).
' Since some RSS feeds' pubDates don't conform to the RFC 822 or 2822 specifications,
' this function is very generic, and will even parse an invalid pubDate.
' Return just the date part (day, month and year), dropping the day-of-week and the time parts.
' The date returned can be in any format since it is mapped to the ReleaseDate Content Item Meta-Data attribute,
' which is just a text string in any format.
'
Function formatPubDate (pubDate As String) As String

    returnDate  = ""

    ' Read up to the first comma and any immediately following whitespace, but don't capture.
    ' Capture the date, everything up to the first colon, which may be preceded by whitespace and digits.
    matchList = CreateObject ("roRegex", "(?:[^,]*,)?\s*(.*?)\s*\d*:", "i").Match (pubDate)

    If matchList.Count () > 1
        returnDate = matchList [1]
    End If

    Return returnDate

End Function
