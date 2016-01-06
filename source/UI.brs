'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'********************************************************************

'
' To switch from using an roPosterScreen to an roGridScreen when displaying categories with leaves:
'   Change uiDisplayCategoryWithLeaves () to uiDisplayCategoryGrid () in two places:
'   uiDisplay () and uiDisplayCategoryWithoutLeaves ()
'

'
' Display the appropriate UI screen depending on the feed type
'
Function uiDisplay (contentItem As Object) As Void

    If contentItem.xxFeedType = "category"
        uiDisplayCategoryWithoutLeaves (contentItem)
                                                        ' Pass in the <categories> or <category> containing <category> child elements
    Else If contentItem.xxFeedType = "leaf"
        uiDisplayCategoryWithLeaves (contentItem.xxChildContentList, 0, contentItem.xxChildNamesList)
        'uiDisplayCategoryGrid (contentItem.xxChildContentList, 0, contentItem.xxChildNamesList)
                                                        ' Pass in the <category> containing the <categoryLeaf> child elements
    Else If contentItem.xxFeedType = "feed"
        ' Read the feed if it is not already cached
        If Not contentItem.xxIsCached
            contentItem.xxChildContentList = parseXmlDocument (contentItem.xxFeedPath)
            contentItem.xxIsCached = True
        End If
        uiDisplayCategoryWithoutLeaves (contentItem.xxChildContentList)
                                                        ' Pass in the <feed> element
    Else If contentItem.xxFeedType = "items"
        uiDisplayCategoryWithoutLeaves (contentItem)
                                                        ' Pass in the <feed> element containing the <item> child elements
    Else
        _debug ("uiDisplay. Invalid Feed Type: contentItem.xxFeedType")
    End If

End Function

'
' A <category> element with child <category> elements is displayed as an roPosterScreen with no filter banner.
'
Function uiDisplayCategoryWithoutLeaves (contentItem As Object, breadLeft = "" As String, breadRight = "" As String) As Void
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roPosterScreen")
    ui.SetMessagePort (port)
    ui.SetCertificatesFile ("common:/certs/ca-bundle.crt")  ' Allow "https" images
    ui.InitClientCertificates ()
    ui.SetBreadcrumbText (breadLeft, breadRight)
    ui.SetListStyle ("flat-category")                       ' Use "flat-episodic" to display description beneath ShortDescriptionLine1/2
    ui.SetContentList (contentItem.xxChildContentList)      ' List of <item> or <category> or <categoryLeaf> elements
    ui.Show ()

    itemIndex = 0
    ui.SetFocusedListItem (0)

    While True
        msg = Wait (0, port) : _logEvent ("uiDisplayCategoryWithoutLeaves", msg)
        If msg <> Invalid
            If Type (msg) = "roPosterScreenEvent"
                If msg.IsScreenClosed ()
                    Exit While
                Else If msg.IsListItemSelected ()
                    itemIndex = msg.GetIndex ()
                    selectedContentItem = contentItem.xxChildContentList [itemIndex]

                    ' Selected item is a <category> node
                    If selectedContentItem.xxFeedType = "category"
                        uiDisplayCategoryWithoutLeaves (selectedContentItem, breadRight, selectedContentItem.Title)

                    ' Selected item is <categoryLeaf> node
                    Else If selectedContentItem.xxFeedType = "leaf"
                        uiDisplayCategoryWithLeaves (selectedContentItem, 0, breadRight, selectedContentItem.Title)
                        'uiDisplayCategoryGrid (selectedContentItem, 0, breadRight, selectedContentItem.Title)

                    ' Selected item is a <feed> node
                    Else If selectedContentItem.xxFeedType = "feed"
                        If Not selectedContentItem.xxIsCached
                            selectedContentItem.xxChildContentList = parseXmlDocument (selectedContentItem.xxFeedPath)  ' Read <feed> node
                            selectedContentItem.xxIsCached = True
                        End If
                        uiDisplayCategoryWithoutLeaves (selectedContentItem.xxChildContentList, breadRight, selectedContentItem.Title)

                    ' Selected item is a content details item
                    Else
                        itemIndex = uiDisplayDetails (contentItem, itemIndex, breadRight, contentItem.Title)    ' Pass in <feed> element
                        ui.SetFocusedListItem (itemIndex)

                    End If
                End If
            End If
        End If
    End While
End Function

'
' A lowest-level <category> element with child <categoryLeaf> elements is displayed as an roPosterScreen with a filter banner.
' To use an roGridScreen instead, change all calls to uiDisplayCategoryWithLeaves () to uiDisplayCategoryGrid ().
' The contentItem passed as a parameter contains xxChildContentList which is a list of content item lists, any one of which
' can be selected for display depending on which name in the names list is selected.
'
Function uiDisplayCategoryWithLeaves (contentItem As Object, nameIndex As Integer, breadLeft = "" As String, breadRight = "" As String) As Void
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roPosterScreen")
    ui.SetMessagePort (port)
    ui.SetCertificatesFile ("common:/certs/ca-bundle.crt")  ' Allow "https" images
    ui.InitClientCertificates ()
    ui.SetBreadcrumbText (breadLeft, breadRight)
    ui.SetListStyle ("flat-category")                       ' Use "flat-episodic" to display description beneath ShortDescriptionLine1/2
    ui.SetListNames (contentItem.xxChildNamesList)
    '
    ' Read in the focused content item if it is not yet cached
    '
    feedContentItem = contentItem.xxChildContentList [nameIndex]                            ' <feed> node for content list to display
    If Not feedContentItem.xxIsCached
        contentItem.xxChildContentList [nameIndex] = parseXmlDocument (feedContentItem.xxFeedPath)  ' Read <feed> node
        feedContentItem = contentItem.xxChildContentList [nameIndex]
        feedContentItem.xxIsCached = True
    End If
    ui.SetContentList (feedContentItem.xxChildContentList)

    itemIndex = 0                       ' Always set initial focus to first item
    ui.SetFocusedListItem (itemIndex)
    ui.Show ()

    focusTimer = CreateObject ("roTimespan")    ' Prevent retrieving feeds if scrolling rapidly through category list names
    focusTimerRunning = False
    listIndex = 0

    '
    ' When the user is scrolling through the list names looking for a particular list,
    ' avoid loading the content list for each list name that is scrolled over.
    ' This is achieved by using a short timer that is started when the user starts scrolling through name lists.
    ' If the user stops scrolling for at least 750ms, then load the content list for the currently focused list name.
    ' TODO: Implement similar logic for Grid Screen.
    '
    While True
        msg = Wait (10, port) : If msg <> Invalid Then _logEvent ("uiDisplayCategoryWithLeaves", msg)
        If (Type (msg) = "Invalid" And focusTimerRunning And focusTimer.TotalMilliseconds () > 750) Or (Type (msg) = "roPosterScreenEvent" And msg.IsListSelected () And msg.GetIndex () <> listIndex)
            focusTimerRunning = False
            ui.SetFocusedListItem (0)
            nameIndex = listIndex
            itemIndex = 0                   ' New list focused, so select the first list item
            ui.SetFocusedListItem (itemIndex)
            feedContentItem = contentItem.xxChildContentList [nameIndex]
            If Not feedContentItem.xxIsCached
                contentItem.xxChildContentList [nameIndex] = parseXmlDocument (feedContentItem.xxFeedPath)
                feedContentItem = contentItem.xxChildContentList [nameIndex]
                feedContentItem.xxIsCached = True
            End If
            ui.SetContentList (feedContentItem.xxChildContentList)
            ui.ClearMessage ()
        Else If Type (msg) = "roPosterScreenEvent"
            If msg.IsScreenClosed ()
                Exit While
            '
            ' When a new list takes focus, don't display it right away, in case the user is rapidly scrolling though lists.
            ' Instead, start a timer and display the list when the timer expires.
            '
            Else If msg.IsListFocused ()
                ui.SetContentList ([])
                ui.ShowMessage ("Retrieving ...")
                ' Keep track of which item was focused on
                listIndex = msg.GetIndex ()
                ' If focus timer is running then stop it, else start a new timer
                focusTimerRunning = True
                focusTimer.Mark ()
            Else If msg.IsListItemSelected ()
                ui.ClearMessage ()
                itemIndex = msg.GetIndex ()
                itemIndex = uiDisplayDetails (contentItem.xxChildContentList [nameIndex], itemIndex, breadRight, contentItem.xxChildNamesList [nameIndex])
                ui.SetFocusedListItem (itemIndex)
            End If
        End If
    End While
End Function

'
' Example code when using an roGridScreen instead of an roPosterScreen to display a category with leaves.
' To use this function, replace all calls to uiDisplayCategoryWithLeaves () with calls to uiDisplayCategoryGrid ().
'
Function uiDisplayCategoryGrid (contentItem As Object, nameIndex As Integer, breadLeft = "" As String, breadRight = "" As String) As Void
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roGridScreen")
    ui.SetMessagePort (port)
    ui.SetCertificatesFile ("common:/certs/ca-bundle.crt")  ' Allow "https" images
    ui.InitClientCertificates ()
    ui.SetDisplayMode ("scale-to-fill")     ' Fit image entirely within the bounding box - dimensions may appear distorted
    'ui.SetDisplayMode ("scale-to-fit")     ' Use this if the image dimensions appear too distorted with "scale-to-fill"
    ui.SetGridStyle ("flat-movie")          ' See the Component Reference for roGridScreen for all the styles available
    'ui.SetGridStyle ("flat-square")
    ui.SetupLists (contentItem.xxChildContentList.Count ())
    ui.SetListNames (contentItem.xxChildNamesList)
    ui.SetBreadcrumbText (breadLeft, breadRight)
    If _getRokuVersion ().IsLegacy
        ui.SetUpBehaviorAtTopRow ("exit")   ' Only way back from the grid screen on legacy firmware
    Else
        ui.SetUpBehaviorAtTopRow ("stop")   ' Use default behavior for post-legacy firmware
    End If

    ' Read in the first content item if it is not yet cached
    feedContentItem = contentItem.xxChildContentList [nameIndex]                            ' <feed> node for content list to display
    If Not feedContentItem.xxIsCached
        contentItem.xxChildContentList [nameIndex] = parseXmlDocument (feedContentItem.xxFeedPath)  ' Read <feed> node
        feedContentItem = contentItem.xxChildContentList [nameIndex]
        feedContentItem.xxIsCached = True
    End If
    ' Display the first content row
    ui.SetContentList (nameIndex, contentItem.xxChildContentList [nameIndex].xxChildContentList)

    ' Display the next content row
    nextIndex = nameIndex + 1
    If nextIndex >= contentItem.xxChildContentList.Count ()
        nextIndex = nameIndex
    End If
    If nextIndex <> nameIndex
        nextContentItem = contentItem.xxChildContentList [nextIndex]
        If Not nextContentItem.xxIsCached
            contentItem.xxChildContentList [nextIndex] = parseXmlDocument (nextContentItem.xxFeedPath)  ' Read <feed> node
            nextContentItem = contentItem.xxChildContentList [nextIndex]
            nextContentItem.xxIsCached = True
        End If
        ui.SetContentList (nextIndex, nextContentItem.xxChildContentList)
    End If

    ui.SetFocusedListItem (nameIndex, 2)    ' Cursor starts in the middle of the row (corresponds to the third item; index = 2)
    ui.Show ()

    While True
        msg = Wait (0, port) : _logEvent ("uiDisplayCategoryGrid", msg)
        If msg <> Invalid
            If Type (msg) = "roGridScreenEvent"
                If msg.IsScreenClosed ()
                    Exit While
                Else If msg.IsListItemFocused ()
                    nameIndex = msg.GetIndex ()
                    itemIndex = msg.GetData ()
                    ' Get the feed data for the focused content row
                    feedContentItem = contentItem.xxChildContentList [nameIndex]
                    ' Read the focused content row if it is not already cached
                    If Not feedContentItem.xxIsCached
                        contentItem.xxChildContentList [nameIndex] = parseXmlDocument (feedContentItem.xxFeedPath)
                        feedContentItem = contentItem.xxChildContentList [nameIndex]
                        feedContentItem.xxIsCached = True
                    End If
                    ' Display the focused content row
                    ui.SetContentList (nameIndex, feedContentItem.xxChildContentList)

                    ' Display the next content row
                    nextIndex = nameIndex + 1
                    If nextIndex >= contentItem.xxChildContentList.Count ()
                        nextIndex = nameIndex
                    End If
                    If nextIndex <> nameIndex
                        nextContentItem = contentItem.xxChildContentList [nextIndex]
                        If Not nextContentItem.xxIsCached
                            contentItem.xxChildContentList [nextIndex] = parseXmlDocument (nextContentItem.xxFeedPath)  ' Read <feed> node
                            nextContentItem = contentItem.xxChildContentList [nextIndex]
                            nextContentItem.xxIsCached = True
                        End If
                        ui.SetContentList (nextIndex, nextContentItem.xxChildContentList)
                    End If

                ' Display the details screen for the selected item
                Else If msg.IsListItemSelected ()
                    nameIndex = msg.GetIndex ()
                    itemIndex = msg.GetData ()
                    itemIndex = uiDisplayDetails (contentItem.xxChildContentList [nameIndex], itemIndex, breadRight, contentItem.xxChildNamesList [nameIndex])
                    ui.SetFocusedListItem (nameIndex, itemIndex)
                End If
            End If
        End If
    End While
End Function

'
' Display the appropriate details screen depending on the feed content type.
' The feedContentItem parameter corresponds to a single <feed> element node, whose xxFeedContentType indicates the media content type, "video", "audio", etc.
' Current only supports "video" content.
' The feed item's xxChildContentList corresponds to the content list of <item> elements displayed by the details screen.
' The index parameter indicates which particular <item> is to be displayed initially. The return index value indicates the last <item> that was displayed before returning.
'
Function uiDisplayDetails (feedContentItem As Object, index As Integer, breadLeft = "" As String, breadRight = "" As String) As Integer

    If feedContentItem.xxFeedContentType = "video"
        index = uiDisplayVideoDetails (feedContentItem.xxChildContentList, index, breadLeft, breadRight)
    Else
        uiSoftError ("uiDisplayDetails", LINE_NUM, "Unsupported Content Type: " + feedContentItem.xxFeedContentType)
    End If

    Return index

End Function

'
' The video details screen is displayed as an roSpringboardScreen
'
Function uiDisplayVideoDetails (contentList As Object, index As Integer, breadLeft = "" As String, breadRight = "" As String) As Integer
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roSpringboardScreen")
    ui.SetMessagePort (port)
    ui.SetCertificatesFile ("common:/certs/ca-bundle.crt")
    ui.InitClientCertificates ()
    ui.SetDisplayMode ("scale-to-fill")
    ui.SetDescriptionStyle ("movie")        ' All tags on the video screen are substituted with Content Meta-Data
    ui.SetBreadcrumbText (breadLeft, breadRight)
    uiDisplayVideoDetailsSetContent (ui, contentList, index)
    ui.Show ()

    While True
        msg = Wait (0, port) : _logEvent ("uiDisplayVideoDetails", msg)
        If msg <> Invalid
            If msg.IsScreenClosed ()
                Exit While
            Else If msg.IsButtonPressed ()
                buttonId = msg.GetIndex ()
                ' Only attempt to play the video if there is at least one media stream
                streams = contentList [index].LookupCI ("Streams")
                If streams <> Invalid And streams.Count () > 0
                    ' Display a blank facade to avoid flashing back to the roSpringboardScreen between videos
                    facade = CreateObject ("roImageCanvas")
                    facade.SetLayer (0, {Color: "#FF000000"})
                    facade.Show ()
                    ' Play the video
                    If buttonId = 0                 ' Play
                        uiPlayVideo (contentList, index)
                        uiDisplayVideoDetailsSetContent (ui, contentList, index)        ' Add/remove Resume button
                    Else If buttonId = 1            ' Play all
                        ' Play each video from the current position
                        While index < contentList.Count ()
                            ' Only play the next video if it has at least one media stream
                            streams = contentList [index].LookupCI ("Streams")
                            If streams <> Invalid And streams.Count () > 0
                                ' Play the next video
                                If Not uiPlayVideo (contentList, index)
                                    ' Either the user exited the video screen with the Back button,
                                    ' or there was an error during video playback
                                    Exit While
                                End If
                            End If
                            ' Select next video
                            index = index + 1
                            If index < contentList.Count ()
                                uiDisplayVideoDetailsSetContent (ui, contentList, index)
                            Else
                                ' After Play All finishes, stay on the last video
                                index = contentList.Count () - 1
                                Exit While
                            End If
                        End While
                        uiDisplayVideoDetailsSetContent (ui, contentList, index)        ' Add/remove Resume button
                    Else If buttonId = 2            ' Resume
                        uiPlayVideo (contentList, index)
                        uiDisplayVideoDetailsSetContent (ui, contentList, index)        ' Add/remove Resume button
                    Else If buttonId = 3            ' Play from beginning
                        REM _setBookmark (contentList [index].ContentId, 0)
                        ' Don't store bookmarks with a zero value; delete until a position notification is received
                        If Not contentList [index].Live
                            _clearBookmark (contentList [index].ContentId)
                            contentList [index].Delete ("playstart")    ' Don't need PlayStart in the content list any more
                        End If
                        uiPlayVideo (contentList, index)
                        uiDisplayVideoDetailsSetContent (ui, contentList, index)        ' Add/remove Resume button
                    End If
                    facade.Close ()
                Else
                    uiSoftError ("uiDisplayVideoDetails", LINE_NUM, "No media streams found for this item")
                    uiDisplayVideoDetailsSetContent (ui, contentList, index)
                End If
            Else If msg.IsRemoteKeyPressed ()
                key = msg.GetIndex ()
                If key = 4                      ' Left - no wraparound
                    If index > 0
                        index = index - 1
                        uiDisplayVideoDetailsSetContent (ui, contentList, index)
                    End If
                Else If key = 5                 ' Right - no wraparound
                    If index < contentList.Count () - 1
                        index = index + 1
                        uiDisplayVideoDetailsSetContent (ui, contentList, index)
                    End If
                End If
            End If
        End If
    End While

    Return index

End Function

'
' Set or replace the current details screen's content.
' Called when a details screen for an <item> is initially displayed,
' or when navigating laterally through <item> elements on the roSpringboardScreen.
'
Function uiDisplayVideoDetailsSetContent (ui As Object, contentList As Object, index As Integer) As Void

    ui.AllowUpdates (False)
    ui.ClearButtons ()
    If contentList [index].Live Or _getBookmark (contentList [index].ContentId) < 10
        ui.AddButton (0, "Play")
        If contentList.Count () > 1 Then ui.AddButton (1, "Play all")
    Else
        ui.AddButton (2, "Resume")
        ui.AddButton (3, "Play from beginning")
        If contentList.Count () > 1 Then ui.AddButton (1, "Play all")
    End If
    ui.AllowNavLeft (contentList.Count () > 1)
    ui.AllowNavRight (contentList.Count () > 1)
    ui.SetStaticRatingEnabled (contentList [index].StarRating <> Invalid)   ' Don't display stars if none in content list
    ui.SetContent (contentList [index])
    ui.AllowUpdates (True)

End Function

'
' The selected video content is played using an roVideoScreen
'
Function uiPlayVideo (contentList As Object, index As Integer) As Boolean

    ' Return True if and only if playback completed normally (end of video reached).
    ' Allows 'Play All' functionality to determine whether it's okay to play the next video.
    normalCompletion = False

    ' Keep track of how long video has been playing, for retry logic
    playTimer = CreateObject ("roTimespan")

    ' Count number of retry attempts following playback failure
    MAX_RETRIES = 3
    numRetries = 0

    ' Make sure we have a valid content index
    If index >= 0 And index < contentList.Count ()

        done = False        ' Set to True when finished or retry limit reached

        ' Keep retrying failed playback attempts
        While Not done

            ' Don't retry unless a failed playback occurs
            done = True

            ' Set up a new screen object for each retry
            port = CreateObject ("roMessagePort")
            ui = CreateObject ("roVideoScreen")
            ui.SetMessagePort (port)
            ui.SetCertificatesFile ("common:/certs/ca-bundle.crt")
            ui.InitClientCertificates ()
            ' Don't attempt to bookmark live content
            If Not contentList [index].Live
                ui.SetPositionNotificationPeriod (10)
                ' Set PlayStart to the currently-bookmarked position.
                ' Not need to set unless we're at least 10 seconds into the video.
                playStart = _getBookmark (contentList [index].ContentId)
                If playStart >= 10
                    contentList [index].PlayStart = playStart
                End If
            End If

            ' Disable Fast-Forward and Rewind for live videos
            If contentList [index].Live
                ui.SetPreviewMode (True)
            End If

            statusMessage = ""      ' Keep track of last status message received

            ui.SetContent (contentList [index])
            ui.Show ()

            While True
                msg = Wait (0, port) : _logEvent ("uiPlayVideo", msg)
                If msg <> Invalid

                    ' The screen is being closed
                    If msg.IsScreenClosed ()
                        Exit While

                    ' Keep track of the playback position
                    Else If msg.IsPlaybackPosition ()
                        ' Don't start bookmarking until we're at least 10 seconds into the video
                        If Not contentList [index].Live And msg.GetIndex () >= 10
                            _setBookmark (contentList [index].ContentId, msg.GetIndex ())
                        End If

                    ' If the stream started then reset the play timer
                    Else If msg.IsStreamStarted ()
                        playTimer.Mark ()

                    ' Playback completed normally. Roku will close the screen after sending an IsScreenClosed event.
                    ' Ensures that if Play All is in use, the next video can be played.
                    Else If msg.IsFullResult ()
                        normalCompletion = True
                        If Not contentList [index].Live
                            _clearBookmark (contentList [index].ContentId)
                            contentList [index].Delete ("playstart")    ' Don't need PlayStart in the content list any more
                        End If

                    ' Store status message to display if a request-failed message occurs
                    Else If msg.IsStatusMessage ()
                        statusMessage = msg.GetMessage ()

                    ' Video playback failed
                    Else If msg.IsRequestFailed ()
                        failIndex = msg.GetIndex ()
                        message = msg.GetMessage ()
                        failMessage = ""
                        unsupportedMessage = ""

                        ' Roku firmware doesn't appear to return a message for a request failed event,
                        ' so use the preceding status message instead.
                        If message = ""
                            message = statusMessage
                        End If

                        ' If a video has been playing for a while, reset the retry count
                        If playTimer.TotalSeconds () > 300
                            numRetries = 0
                            playTimer.Mark ()
                        End If

                        numRetries = numRetries + 1

                        If numRetries > MAX_RETRIES Or failIndex = -4   ' Don't retry if no video streams
                            ' Roku firmware only returns a number for a failure; translate to a message to display to the user
                            If failIndex >= -5 And failIndex <= 0
                                failMessage = [ "Network error : server down or unresponsive, server is unreachable, network setup problem on the client.",
                                                "HTTP error: malformed headers or HTTP error result.",
                                                "Connection timed out.",
                                                "Unknown error.",
                                                "Empty list; no streams were specified to play.",
                                                "Media error; the media format is unknown or unsupported." ][-failIndex]
                                If failIndex = -4 Or failIndex = -5
                                    unsupportedMessage = "Possibly the feed has no Roku-compatible video content."
                                End If
                            Else
                                failMessage = "Unknown failure code: " + failIndex.ToStr ()
                            End If

                            ' Debugging info - list the streams for this content item
                            For i = 0 To contentList [index].Streams.Count () - 1
                                stream = contentList [index].Streams [i]
                                _debug ("uiPlayVideo. Stream[" + i.ToStr () + "]. Url: " + stream.Url)
                            End For

                            uiDisplayMessage ("Video Playback Failed", [failMessage, message, unsupportedMessage])
                        Else
                            ' Retry the failed video
                            _debug ("uiPlayVideo. Retry Attempt #" + numRetries.ToStr ())
                            uiDisplayCanvasMessage ("Video Playback Failed. " + Chr (10) + Chr (10) + "Retrying ....", 3000)
                            done = False
                        End If
                        ' Close the screen, exiting the loop when the IsScreenClosed event is received
                        ui.Close ()
                    End If
                End If
            End While
        End While

    End If

    Return normalCompletion

End Function

'
' Display an message on an image canvas.
' Keep message displayed until the timeout expires or the user presses a key.
'
Function uiDisplayCanvasMessage (message As String, timeout = 0 As Integer) As Void
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roImageCanvas")
    ui.SetMessagePort (port)
    ui.SetLayer (0, {Color: "#FF101010"})
    ui.SetLayer (1, {Text: message, TextAttrs:  {Color: "#FFEBEBEB", Font: "Large", HAlign: "HCenter", VAlign: "VCenter"}})
    ui.Show ()
    msg = Wait (timeout, port) : _logEvent ("uiDisplayCanvasMessage", msg)
    ui.Close ()
End Function

'
' Display a message dialog. textList is an array of Strings, each one being a single line of text to display
'
Function uiDisplayMessage (title As String, textList As Object) As Void
    port = CreateObject ("roMessagePort")
    ui = CreateObject ("roMessageDialog")
    ui.SetMessagePort (port)
    ui.SetTitle (title)
    For Each textItem In textList
        ui.SetText (textItem)
    End For
    ui.AddButton (1, "OK")
    ui.EnableBackButton (True)
    ui.Show ()
    While True
        msg = Wait (0, port) : _logEvent ("uiDisplayMessage", msg)
        If msg <> Invalid
            If Type (msg) = "roMessageDialogEvent"
                If msg.IsScreenClosed ()
                    Exit While
                Else If msg.IsButtonPressed ()
                    ui.Close ()
                End If
            End If
        End If
    End While
End Function

'
' Display a message for a recoverable error
'
Function uiSoftError (functionString As String, lineNumber As Integer, errorString As String) As Void
    msg = "Soft error in " + functionString + " on line #" + lineNumber.ToStr ()
    _debug ("uiSoftError. " + msg + ". " + errorString)
    uiDisplayMessage ("Error", [errorString])
End Function

'
' Display an error message then terminate the channel if an unrecoverable error occurs
'
Function uiFatalError (functionString As String, lineNumber As Integer, errorString As String) As Void
    msg = "Fatal error in " + functionString + " on line #" + lineNumber.ToStr ()
    _debug ("uiFatalError. " + msg + ". " + errorString)
    uiDisplayMessage ("Fatal Error", [msg, errorString])
    Stop
End Function
