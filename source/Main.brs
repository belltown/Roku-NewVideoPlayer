'********************************************************************
'
'       NewVideoPlayer -- Example Multi-Level Roku Channel
'
' Copyright (c) 2015, belltown. All rights reserved. See LICENSE.txt
'
'*********************************************************************
'
' Source files:
'   Main.brs        - This file
'   UI.brs          - User-interface code including message dialogs
'   UITheme.brs     - The channel's UI theme
'   Parse.brs       - Top-level parsing of Xml documents
'   RokuFeed.brs    - Handles parsing of Roku SDK example videoplayer-compatible feeds
'   RssFeed.brs     - Handles standard RSS elements and calls other functions to handle MRSS/iTunes extensions
'   AtomFeed.brs    - Add code here to support Atom Feeds (not currently supported)
'   Mrss.brs        - Handles MRSS RSS extensions. Go here to find what MRSS elements/attributes are supported
'   Itunes.brs      - Handles iTunes RSS extensions. Go here to find what iTunes elements/attributes are supported
'   Url.brs         - Utility functions to read data from a local path or external url
'   Utils.brs       - General-purpose utility functions
'   FormatJson.brs  - Only needed for version 3.1 firmware, which does not have native BrightScript FormatJSON support
'

' The _DEBUG_ON function MUST be defined once. Return True to enable debug-logging.
Function _DEBUG_ON () As Boolean : Return True : End Function

' The maximum number of feed items returned (0 = no limit)
Function MAX_ITEMS () As Integer : Return 20 : End Function

Sub Main ()

    ' Initialize the application-wide theme. Go to UITheme.brs to make changes to your application theme.
    uiThemeInit ()

    ' Parse the top-level Xml file, passing the resultant hierarchical content list to the UI display function
    uiDisplay (parseXmlDocument ("pkg:/xml/categories.xml"))

    'Some other example feeds...

    'uiDisplay (parseXmlDocument ("http://rokudev.roku.com/rokudev/examples/videoplayer/xml/categories.xml"))
    'uiDisplay (parseXmlDocument ("http://rokudev.roku.com/rokudev/examples/videoplayer/xml/themind.xml"))
    'uiDisplay (parseXmlDocument ("http://feeds.feedburner.com/RokuNewest"))
    'uiDisplay (parseXmlDocument ("http://feeds.twit.tv/brickhouse_video_small.xml"))
    'uiDisplay (parseXmlDocument ("https://www.whitehouse.gov/podcast/video/press-briefings/rss.xml"))
    'uiDisplay (parseXmlDocument ("http://feeds.feedburner.com/daily_tech_news_show?format=xml"))

End Sub
