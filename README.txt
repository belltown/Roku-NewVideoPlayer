=============================================================================
 W A R N I N G !!!
=============================================================================
 THIS CODE USES THE ROKU LEGACY SDK, WHICH IS SCHEDULED TO BE DEPRECATED!!!

 According the Roku Developer Blog: https://blog.roku.com/developer/2017/02/01/legacy-sdk/,
 as of July 1, 2017, no new channels may use the Legacy SDK
 as of January 1, 2018, no channel updates may use the Legacy SDK
 as of January 1, 2019, Legacy SDK components will be removed from the Roku OS

==============================================================================

NewVideoPlayer -- An example Roku channel with multi-level categories

A completely re-written and enhanced version of the Roku SDK Example 'videoplayer' Channel.

The original Roku SDK Example videoplayer channel code can be found here:
http://sourceforge.net/p/rokusdkexamples/code/HEAD/tree/trunk/rokusdkexamples-code/videoplayer/

Features:

-   Unlimited <category> levels, each displayed using an roPosterScreen.
    The lowest <category> having <categoryLeaf> elements is displayed as an roPosterScreen with a filter banner.
    An roGridScreen can be used instead of the roPosterScreen with a filter banner, by changing 2 lines of code.
    All <category> and nested <category> elements must be specified in the top-level Xml file.
    Each <categoryLeaf> must refer to a separate <feed> file containing the feed's <item> elements.

-   The top-level Xml file may also be a Roku <feed> file, or an <rss> file.

-   RSS files may contain RSS 2.0 elements, MRSS extensions, and iTunes extensions.
    Note: The RSS/MRSS/iTunes extensions are ONLY supported in an <rss> feed, NOT in a Roku <feed>.

-   A "feed" attribute may be specified for a <category> element, only if there are no subordinate <categoryLeaf> elements.

-   A Roku feed (but not an RSS feed) may appear inline in the top-level Xml file,
    subordinate to a <categories> or <category> element, but not a <categoryLeaf>.

-   Xml files may be referenced either using a local Roku filename or a remote url (http or https).

-   Xml element and attribute names are case-insensitive.

-   See pkg:/xml/categories.xml and pkg:/xml/feed.xml for example feeds.

-   See RokuFeed.brs for a list of supported Xml elements for a Roku feed.

-   See Mrss.brs for a list of supported MRSS elements for an RSS feed.

-   See Itunes.brs for a list of supported iTunes elements for an RSS feed.

-   Supports Play/Resume, as well as 'Play all' and 'Play from beginning'.

-   The last play position for the previous 10 videos played is stored for 'Resume' functionality.

-   Should work on an SD TV, even if no SD streams are specified in the Xml feed file.

-   Supports both MP4 and HLS video streams.

-   Supports 'https' video and image urls.

-   Compatible with the Xml files used by the Roku SDK videoplayer example (TED Talks Videos).

-   Should work on all Roku firmware versions, including legacy 3.1 firmware.


Usage:

To get a working channel with your own feed and artwork, all you need to do is modify 'Main.brs' to point to your
feed file (unless it's already called 'categories.xml'), modify 'manifest' to contain your own manifest data,
modify 'UITheme.brs' with any of your own theme attributes, then install your own artwork (e.g. in pkg:/images).
If you want to use an roGridScreen instead of an roPosterScreen, then change both calls to
uiDisplayCategoryWithLeaves () to uiDisplayCategoryGrid () in UI.brs.

Anyone using this code, whether modified or unmodifed, is responsible for their own testing (including of this example code).

Do not expect any support whatsoever for this code. You may contact 'belltown' via the Roku forums if you find any bugs;
however, do not expect to get much help with adding additional functionality, writing/debugging/testing your own code, etc.


Implementation:

The top-level Xml <categories> file and all referenced "feed" Xml files are parsed top-down.

Each <category> element, including the root <categories> element, is stored as a Content Meta-Data List (roAssociativeArray).

Each element's subordinate <category> elements are stored in their parent's Content Meta-Data List
as a "custom" Meta-Data item: xxChildContentList.

Each lowest-level <category> element (<categoryLeaf> parent) is stored as a Content Meta-Data List with "custom" items:
xxChildNamesList (an array of category names for the roPosterScreen filter banner),
and xxChildContentList (an array of Content Meta-Data Lists, one for each <categoryLeaf>,
each of which corresponds to a video <item> element in the video <feed> element).
The meta-data item, xxFeedType, indicates the type of CHILD elements contained in its xxChildContentList:
"category": <category> elements; "leaf": <categoryLeaf> elements; "feed": a single <feed> element; "items": <item> elements.

<feed> elements may be specified inline in a categories file, or externally in a feed file (local file or remote url).
External feed files may be specified using the "feed" attribute on a <categories>, <category> or <categoryLeaf> node.
An external feed file will not be read until its contents are to be displayed, thus minimizing the channel startup time.
External feed files are read only once, and stored in the hierarchical content list data structure.

Only a single <feed> element is handled for each <category>.
For channels whose feeds contain large numbers of <item> elements, a content list containing all <item> elements is generated.
However, the function MAX_ITEMS () defined in Main.brs, puts a limit on the number of <item> elements handled (20 by default).

The feed Content Type may be specified using the "contentType" attribute of the <feed> element.
Currently, only the "video" Content Type is supported; however, other content types could easily be implemented.

This design has not been optimized for performance, so depending on which Roku model you're using,
you may notice long loading times if your feeds contain large numbers of items.
