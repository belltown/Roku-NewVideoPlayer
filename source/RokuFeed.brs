'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'*********************************************************************

'
' Parse a Roku <feed> Xml document.
'
' See parseRokuItem () for a list of supported Xml elements.
' Note that for a Roku <feed>, only Roku elements are supported (No RSS, MRSS, iTunes extensions).
'
' Parse a Roku <feed> Xml document returning a Content List of <item> Content Items.
' Returns a feed Content Item containing an xxChildContentList of all subordinate <item> elements.
' Only a single <feed> node is supported for each category.
'
' The Roku Xml document is processed in two stages:
' First, the document is parsed, and a 'roku' structure is created containing an array of item data fields.
' Second, the 'roku' structure is read and used to populate the ContentItem structures.
' This could be done in a single step; however, separating the Xml file parsing logic and the
' mapping of parsed data to content item attributes seemed at the time to make the implementation easier.
'
Function getRokuContent (xml As Object) As Object

    contentItem = {}

    ' Parse the entire Roku feed returning a temporary 'roku' data structure that
    ' contains the header info (e.g "title), and an array, itemList, containing
    ' an element for each <item>
    roku = parseRokuFeedXml (xml)

    ' Use a fixed-length array for storing the content item list
    contentItem.xxChildContentList = CreateObject ("roArray", roku.itemList.Count (), False)

    ' Set up content item Meta-Data
    contentItem.Title = roku.title
    contentItem.xxFeedContentType = roku.feedContentType    ' Only "video" supported currently
    contentItem.xxIsCached = True
    contentItem.xxFeedType = "items"

    ' Set up each content item
    ' Limit the maximum number of <item> elements handled (0 = no limit)
    For index = 0 To roku.itemList.Count () - 1
        If index < MAX_ITEMS () Or MAX_ITEMS () = 0
            contentItem.xxChildContentList.Push (getRokuItemContent (roku, index))
        End If
    End For

    Return contentItem

End Function

'
' Take the item data from a specified roku.itemList element and use it to
' populate a ContentItem structure
'
Function getRokuItemContent (roku As Object, index As Integer) As Object

    contentItem = {}

    item = roku.itemList [index]

    ' Set image based on item's sdImg/hdImg atributes
    sdImg = item.sdImg
    hdImg = item.hdImg
    If sdImg = "" Then sdImg = hdImg
    If hdImg = "" Then hdImg = sdImg

    ' If no sdImg/hdImg attributes specified for the item, then default to the <feed> sd_img/hd_img, if any
    If sdImg = "" Then sdImg = roku.sdImg
    If hdImg = "" Then hdImg = roku.hdImg

    streamFormat = item.streamFormat

    switchingStrategy = item.switchingStrategy

    contentType = item.contentType

    contentId = item.contentId

    title = item.title
    If title = "" Then title = roku.title

    ' synopsis (if present) is used for the Description field on the roSpringboardScreen
    synopsis = item.synopsis

    ' description (if present) is used for ShortDescriptionLine2 on the roPosterScreen
    description = item.description

    ' Make sure we have something for the Description field on the roSpringboardScreen
    If synopsis = "" Then synopsis = description

    runtime = item.runtime

    director = item.director

    actorList = item.actorList

    genreList = item.genreList

    rating = item.rating

    releaseDate = item.releaseDate

    starRating = item.starRating

    srt = item.srt

    sdBifUrl = item.sdBifUrl
    hdBifUrl = item.hdBifUrl
    If sdBifUrl = "" Then sdBifUrl = hdBifUrl
    If hdBifUrl = "" Then hdBifUrl = sdBifUrl

    cc = item.cc

    ' If the device is running in SD mode, there must be at least one SD stream specified.
    ' If the content contains no SD streams, but the device is running in SD mode,
    ' then add an SD stream corresponding to the lowest bitrate HD stream,
    ' to ensure there is at least one playable stream.
    hasHD = False
    hasSD = False
    streamList = item.streamList
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

    fullHD = item.fullHD

    ' If no contentId was specified, then make one out of the hash of the first stream url
    If contentId = "" And streamList.Count () > 0
        contentId = _hash (streamList [0].url)
    End If

    ' Set the content id for each media stream
    For Each stream In streamList
        stream.contentId = contentId
    End For

    ' Sanitize text fields
    title = _xmlEntityDecode (_stripHtmlTags (title))

    synopsis = _xmlEntityDecode (_stripHtmlTags (synopsis))

    description = _xmlEntityDecode (_stripHtmlTags (description))

    For index = 0 To genreList.Count () - 1
        genreList [index] = _xmlEntityDecode (_stripHtmlTags (genreList [index]))
    End For

    For index = 0 To actorList.Count () - 1
        actorList [index] = _xmlEntityDecode (_stripHtmlTags (actorList [index]))
    End For

    live = item.live

    ' Set up the Content Meta-Data, only setting fields that have data, to minimize Content Item size
    contentItem.HDBranded               = hasHD Or fullHD
    contentItem.Live                    = live
    contentItem.IsHD                    = hasHD Or fullHD
    contentItem.FullHD                  = fullHD
    contentItem.ContentId               = contentId
    contentItem.Streams                 = streamList
    contentItem.ContentType             = contentType
    contentItem.StreamFormat            = streamFormat
    If cc = True                        Then contentItem.ClosedCaptions         = True
    If srt <> ""                        Then contentItem.SubtitleUrl            = srt
    If title <> ""                      Then contentItem.Title                  = title
    If title <> ""                      Then contentItem.ShortDescriptionLine1  = title
    If sdImg <> ""                      Then contentItem.SDPosterUrl            = sdImg
    If hdImg <> ""                      Then contentItem.HDPosterUrl            = hdImg
    If rating <> ""                     Then contentItem.Rating                 = rating
    If runtime > 0                      Then contentItem.Length                 = runtime
    If synopsis <> ""                   Then contentItem.Description            = synopsis
    If director <> ""                   Then contentItem.Director               = director
    If sdBifUrl <> ""                   Then contentItem.SDBifUrl               = sdBifUrl
    If hdBifUrl <> ""                   Then contentItem.HDBifUrl               = hdBifUrl
    If starRating <> ""                 Then contentItem.StarRating             = starRating
    If releaseDate <> ""                Then contentItem.ReleaseDate            = releaseDate
    If description <> ""                Then contentItem.ShortDescriptionLine2  = description
    If switchingStrategy <> ""          Then contentItem.SwitchingStrategy      = switchingStrategy
    If genreList.Count () > 0           Then contentItem.Categories             = genreList
    If actorList.Count () > 0           Then contentItem.Actors                 = actorList

    Return contentItem

End Function

'
' The first step in processing a Roku feed is to parse the feed document, using the
' parsed data to populate a 'roku' structure, which contains some header data and
' and itemList with an entry for each parsed item.
' getRokuItemContent () will later be called to take this data and construct
' a ContentItem structure.
'
Function parseRokuFeedXml (xml As Object) As Object

    ' Elements and attributes that are not within an <item> element
    feed = parseRokuHeader (xml)

    ' Handle each <item>
    feed.itemList = []
    For Each item in xml.GetNamedElementsCI ("item")
        feed.itemList.Push (parseRokuItem (item))
    End For

    Return feed

End Function

'
' Parse the header items for a Roku <feed>.
'
' The Roku videoplayer SDK example has no supported attributes,
' and defines two elements <resultLength> and <endIndex>, neither of which are used.
'
'   Additional <feed> attributes supported by this example channel are:
'       content_type            - "video" is the only supported feed content type for now
'       sd_img/sdImg            - SD image path (if not specified for the <item> elements)
'       hd_img/hdImg            - HD image path (if not specified for the <item> elements)
'
Function parseRokuHeader (xml As Object) As Object

    header = {}

    ' <feed contentType="video">
    ' Not used in the Roku SDK videoplayer example, but provides a hook to
    ' allow future support for feeds other that video feeds
    header.feedContentType = _getXmlAttrString (xml, "content_type", "video")

    ' <feed title="Feed title">     - Used as the right breadcrumb on items' roSpringboardScreen
    header.title = _getXmlAttrString (xml, "title")

    ' Allow <feed> element to contain image attributes to act as defaults for the subordinate <item> elements
    header.sdImg = _getXmlAttrString (xml, "sd_img")
    If header.sdImg = "" Then header.sdImg = _getXmlAttrString (xml, "sdImg")
    header.hdImg = _getXmlAttrString (xml, "hd_img")
    If header.hdImg = "" Then header.hdImg = _getXmlAttrString (xml, "hdImg")
    ' If sdImg missing then use hdImg and vice-versa
    If header.sdImg = "" Then header.sdImg = header.hdImg
    If header.hdImg = "" Then header.hdImg = header.sdImg

    ' <resultLength> - not currently used - feed paging is not currently implemented

    ' <endIndex> - not currently used

    Return header

End Function

'
' Parse a single <item> element for a Roku <feed>
'
' Standard item attributes and elements (from Roku videoplayer SDK example):
'
'   <item> attributes:
'       sdImg                   - SD image path (if missing, defaults to hdImg)
'       hdImg                   - HD image path (if missing, defaults to sdImg)
'
'   <item> elements:
'       <title>                 - Item title
'       <contentId>             - Uniquely identifies the item for bookmarking and Roku logging (defaults to hash of media streamUrl)
'       <contentType>           - "episode" (or "Talk") for roSpringboardScreen artwork in landscape, otherwise "movie" for portrait
'       <contentQuality>        - SD (default) or HD - used if media streamQuality is not set
'       <media>                 - One element per media stream. Several media streams of different bitrates may be specified
'           <streamFormat>      - "mp4" or "hls"; used if the streamFormat additional item element not specified
'           <streamQuality>     - SD or HD
'           <streamBitrate>     - An integer bitrate in kbps for this stream
'           <streamUrl>         - The url for the media stream
'       <synopsis>              - Used as the Description on the item's roSpringboardScreen
'       <genres>                - One element per genre, used to set the Categories on the item's roSpringboardScreen
'       <runtime>               - An integer length of the content in seconds
'
' Additional item elements allowed:
'
'   <description>               - Used as the item's ShortDescriptionLine2 (and Description if <synopsis> is missing)
'   <streamFormat>              - "mp4" or "hls"
'   <switchingStrategy>         - The SwitchingStrategy used when <streamFormat> is "hls". Default is "full-adaptation"
'   <fullHD>                    - "True" if the item was encoded at 1080p resolution
'   <rating>                    - The Rating, e.g. "PG-13"
'   <starRating>                - The StarRating, an integer from 1 to 100
'   <releaseDate>               - The ReleaseDate, a string item in any date format
'   <director>                  - The Director
'   <srt>                       - The path to a subtitle's file; sets the SubtitleUrl attribute
'   <cc>                        - "True" to show the closed-captions indicator
'   <sdBifUrl>                  - Url for SD trick modes (not yet tested)
'   <hdBifUrl>                  - Url for HD trick modes (not yet tested)
'   <actors>                    - One element per actor, used to set the Actors on the item's roSpringboardScreen
'   <live>                      - "True" if content is for a live stream
'
Function parseRokuItem (xml As Object) As Object

    item = {}

    ' Extract <item> attributes

    item.sdImg = _getXmlAttrString (xml, "sdImg")
    item.hdImg = _getXmlAttrString (xml, "hdImg")

    ' Just in case the same attribute names as in <feed> are used
    If item.sdImg = "" Then item.sdImg = _getXmlAttrString (xml, "sd_img")
    If item.hdImg = "" Then item.hdImg = _getXmlAttrString (xml, "hd_img")

    ' Extract <item> elements

    item.title = _getXmlString (xml, "title")

    item.contentId = _getXmlString (xml, "contentId")

    item.contentType = _getXmlString (xml, "contentType", "episode")
    If LCase (item.contentType) = "talk" Then item.contentType = "episode"  ' SDK videoplayer example xml files use 'Talk' for their videos

    ' Default contentQuality for <item> is SD. The <media> contentQuality overrides the <item> contentQuality
    item.contentQuality = UCase (_getXmlString (xml, "contentQuality", "SD"))

    ' Build an array of streams from the <media> elements
    mediaStreamUrl = ""
    mediaStreamFormat = ""
    item.streamList = []
    For Each media In xml.GetNamedElementsCI ("media")
        stream = {}
        ' Use the first media streamFormat ("mp4"/"hls") as the item's streamFormat
        If mediaStreamFormat = ""
            mediaStreamFormat = _getXmlString (media, "streamFormat")
        End If
        stream.quality      = UCase (_getXmlString (media, "streamQuality", item.contentQuality)) <> "SD"
        stream.bitrate      = _getXmlInteger (media, "streamBitrate", 0)
        stream.url          = _getXmlString (media, "streamUrl")
        If mediaStreamUrl = ""
            mediaStreamUrl = stream.url
        End If
        ' stream.contentId is set up later
        item.streamList.Push (stream)
    End For

    item.synopsis = _getXmlString (xml, "synopsis")

    ' Extract the genres data from the Xml (allow for either <genres> or <genre> elements to be used)
    item.genreList = []
    genreItemList = xml.GetNamedElementsCI ("genres")
    For Each genre In genreItemList
        genreItem = genre.GetText ().Trim ()
        If genreItem <> ""
            item.genreList.Push (genreItem)
        End If
    End For
    genreItemList = xml.GetNamedElementsCI ("genre")
    For Each genre In genreItemList
        genreItem = genre.GetText ().Trim ()
        If genreItem <> ""
            item.genreList.Push (genreItem)
        End If
    End For

    item.runtime = _getXmlInteger (xml, "runtime")

    ' The following elements are custom elements, not used in the Roku SDK videoplayer example ...

    item.description = _getXmlString (xml, "description")

    ' Use the media streamFormat (e.g. "hls") if one was specified
    item.streamFormat = mediaStreamFormat

    item.fullHD = _getXmlBoolean (xml, "fullHD")

    ' If there was no media streamFormat specified, then use the item streamFormat
    If item.streamFormat = ""
        item.streamFormat = LCase (_getXmlString (xml, "streamFormat"))
    End If

    ' If no streamFormat specified, examine the url
    If item.streamFormat = ""
        If LCase (Right (mediaStreamUrl, 5)) = ".m3u8"
            item.streamFormat = "hls"
        Else
            item.streamFormat = "mp4"
        End If
    End If

    ' For streamFormat of "hls", specify switchingStrategy
    If item.streamFormat = "hls"
        item.switchingStrategy = LCase(_getXmlString (xml, "switchingStrategy", "full-adaptation"))
    Else
        item.switchingStrategy = ""
    End If

    item.rating = _getXmlString (xml, "rating")

    item.starRating = _getXmlString (xml, "starRating")

    item.releaseDate = _getXmlString (xml, "releaseDate")

    item.director = _getXmlString (xml, "director")

    item.srt = _getXmlString (xml, "srt")

    item.cc = _getXmlBoolean (xml, "cc")

    item.sdBifUrl = _getXmlString (xml, "sdBifUrl")
    item.hdBifUrl = _getXmlString (xml, "hdBifUrl")

    ' Extract the actors data from the Xml (allow for either <actors> or <actor> elements to be used)
    item.actorList = []
    actorItemList = xml.GetNamedElementsCI ("actors")
    For Each actor In actorItemList
        actorItem = actor.GetText ().Trim ()
        If actorItem <> ""
            item.actorList.Push (actorItem)
        End If
    End For
    actorItemList = xml.GetNamedElementsCI ("actor")
    For Each actor In actorItemList
        actorItem = actor.GetText ().Trim ()
        If actorItem <> ""
            item.actorList.Push (actorItem)
        End If
    End For

    item.live = _getXmlBoolean (xml, "live", False)

    Return item

End Function
