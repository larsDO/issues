
@import <Foundation/CPObject.j>
@import "CPDate+Additions.j"
@import "FilterBar.j"
@import "IssueWebView.j"
@import "PriorityTableDataView.j"
@import "NewIssueWindowController.j"

@implementation IssuesController : CPObject
{
    Repository  repo @accessors;

    @outlet CPView      detailParentView;
    @outlet CPView      noIssuesView;
    @outlet CPView      noRepoView;
    @outlet CPView      loadingIssuesView;
            CPView      displayedView;
            FilterBar   filterBar;

    @outlet CPTableView issuesTableView @accessors;
    @outlet CPWebView   issueWebView @accessors;

    CPString    displayedIssuesKey @accessors;

    CPArray     filteredIssues;
    CPString    searchString;
    unsigned    searchFilter;
}

- (void)awakeFromCib
{
    displayedIssuesKey = "openIssues";

    [self showView:noRepoView];

    var desc = [CPSortDescriptor sortDescriptorWithKey:@"number" ascending:YES],
        ID = [[CPTableColumn alloc] initWithIdentifier:"number"],
        dataView = [CPTextField new];

    [dataView setAlignment:CPRightTextAlignment];
    [dataView setLineBreakMode:CPLineBreakByTruncatingTail];
    [dataView setValue:[CPColor colorWithHexString:@"929496"] forThemeAttribute:@"text-color"];
    [dataView setValue:[CPColor whiteColor] forThemeAttribute:@"text-color" inState:CPThemeStateSelectedDataView];
    [dataView setValue:[CPFont boldSystemFontOfSize:12] forThemeAttribute:@"font" inState:CPThemeStateSelectedDataView];
    [dataView setValue:CGInsetMake(0,10,0,0) forThemeAttribute:@"content-inset"];
    [dataView setValue:CPCenterVerticalTextAlignment forThemeAttribute:@"vertical-alignment"];

    [[ID headerView] setStringValue:"ID"];
    [ID setDataView:dataView];
    [ID setWidth:50.0];
    [ID setMinWidth:50.0];
    [ID setEditable:YES];
    [ID setSortDescriptorPrototype:desc];
    [ID setResizingMask:CPTableColumnUserResizingMask];

    [issuesTableView addTableColumn:ID];

    var desc = [CPSortDescriptor sortDescriptorWithKey:@"title" ascending:YES],
        title = [[CPTableColumn alloc] initWithIdentifier:"title"];

    [[title headerView] setStringValue:"Title"];
    [title setWidth:420.0];
    [title setMinWidth:50.0];
    [title setEditable:YES];
    [title setSortDescriptorPrototype:desc];
    [title setResizingMask:CPTableColumnAutoresizingMask|CPTableColumnUserResizingMask];

    [issuesTableView addTableColumn:title];

    var desc = [CPSortDescriptor sortDescriptorWithKey:@"votes" ascending:YES],
        votes = [[CPTableColumn alloc] initWithIdentifier:"votes"];

    [[votes headerView] setStringValue:"Votes"];
    [votes setWidth:60.0];
    [votes setMinWidth:50.0];
    [votes setEditable:YES];
    [votes setSortDescriptorPrototype:desc];
    [votes setResizingMask:CPTableColumnUserResizingMask];

    [issuesTableView addTableColumn:votes];

    var desc = [CPSortDescriptor sortDescriptorWithKey:@"created_at" ascending:YES],
        date = [[CPTableColumn alloc] initWithIdentifier:"created_at"];

    [[date headerView] setStringValue:"Created"];
    [date setWidth:120.0];
    [date setMinWidth:50.0];
    [date setEditable:YES];
    [date setSortDescriptorPrototype:desc];
    [date setResizingMask:CPTableColumnUserResizingMask];

    [issuesTableView addTableColumn:date];

    var desc = [CPSortDescriptor sortDescriptorWithKey:@"updated_at" ascending:YES],
        updated = [[CPTableColumn alloc] initWithIdentifier:"updated_at"];

    [[updated headerView] setStringValue:"Updated"];
    [updated setWidth:120.0];
    [updated setMinWidth:50.0];
    [updated setEditable:YES];
    [updated setSortDescriptorPrototype:desc];
    [updated setResizingMask:CPTableColumnUserResizingMask];

    [issuesTableView addTableColumn:updated];

    var desc = [CPSortDescriptor sortDescriptorWithKey:@"position" ascending:YES],
        priority = [[CPTableColumn alloc] initWithIdentifier:"position"],
        priorityDataView = [PriorityTableDataView new];

    [[priority headerView] setStringValue:"Priority"];
    [priority setDataView:priorityDataView];
    [priority setWidth:60.0];
    [priority setMinWidth:50.0];
    [priority setEditable:YES];
    [priority setSortDescriptorPrototype:desc];
    [priority setResizingMask:CPTableColumnUserResizingMask];

    [issuesTableView addTableColumn:priority];

    [issuesTableView setTarget:self];
    [issuesTableView setDoubleAction:@selector(openIssueInNewWindow:)];
    [issuesTableView setUsesAlternatingRowBackgroundColors:YES];
    [issuesTableView setColumnAutoresizingStyle:CPTableViewUniformColumnAutoresizingStyle];
    [issuesTableView registerForDraggedTypes:[@"RepositionIssueDragType"]];


    filterBar = [[FilterBar alloc] initWithFrame:CGRectMake(0, 0, 400, 32)];
    [filterBar setAutoresizingMask:CPViewWidthSizable];
    [filterBar setDelegate:self];
    searchFilter = 0;

    [[CPNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(issueChanged:)
                                                 name:GitHubAPIIssueDidChangeNotification
                                               object:nil];
}

- (id)init
{
    if (self = [super init])
    {
        displayedIssuesKey = "openIssues";
    }

    return self;
}

- (@action)takeIssueTypeFrom:(id)sender
{
    [self setDisplayedIssuesKey:[sender selectedTag]];
}

- (void)setDisplayedIssuesKey:(CPString)aKey
{
    displayedIssuesKey = aKey;
    if (!repo)
        return;

    [issuesTableView reloadData];

    [self searchFieldDidChange:nil];
    [self selectIssueAtIndex:-1];
}

- (void)selectIssueAtIndex:(unsigned)index
{
    var indexSet = index < 0 ? [CPIndexSet indexSet] : [CPIndexSet indexSetWithIndex:index];

    if (index >= 0)
        [issuesTableView scrollRowToVisible:index];

    [issuesTableView selectRowIndexes:indexSet byExtendingSelection:NO];
    [self tableViewSelectionDidChange:nil];
}

- (id)selectedIssue
{

    var row = [issuesTableView selectedRow],
        item = nil;

    if (row >= 0 && repo)
    {
        if ([filteredIssues count])
            item = [filteredIssues objectAtIndex:row];    
        else if ([repo[displayedIssuesKey] count])
            item = [repo[displayedIssuesKey] objectAtIndex:row];
    }

    return item;
}

- (void)issueChanged:(CPNotification)aNote
{
    var issue = [aNote object];
    if (issue === [issueWebView issue])
    {
        [issuesTableView reloadData];
        [self searchFieldDidChange:nil];
        [self tableView:issuesTableView sortDescriptorsDidChange:nil];

        var newIndex = [(filteredIssues || repo[displayedIssuesKey]) indexOfObject:issue];
        [self selectIssueAtIndex:newIndex];        
    }
}

- (void)validateToolbarItem:(CPToolbarItem)anItem
{
    var hasSelection = [self selectedIssue] !== nil,
        identifier = [anItem itemIdentifier];

    if (identifier === "openissue")
        return displayedIssuesKey === "closedIssues" && hasSelection;
    else if (identifier === "closeissue")
        return displayedIssuesKey === "openIssues" && hasSelection;
    else if (identifier === "commentissue")
        return hasSelection;
    else 
        return !!repo;
}

- (@action)openIssueInNewWindow:(id)sender
{
    if ([CPPlatform isBrowser] && ![CPPlatformWindow supportsMultipleInstances])
        return;

    var issue = [self selectedIssue];
    if (issue === nil)
        return;

    var newWindow = [[CPWindow alloc] initWithContentRect:CGRectMake(100, 100, 800, 600) styleMask:CPTitledWindowMask|CPClosableWindowMask|CPMiniaturizableWindowMask|CPResizableWindowMask];
    [newWindow setMinSize:CGSizeMake(300, 300)];

    if ([CPPlatform isBrowser])
    {
        var platformWindow = [[CPPlatformWindow alloc] initWithContentRect:CGRectMake(100, 100, 800, 600)];
        [newWindow setPlatformWindow:platformWindow];
        [newWindow setFullBridge:YES];
    }

    var contentView = [newWindow contentView],
        webView = [[IssueWebView alloc] initWithFrame:[contentView bounds]];

    [webView setAutoresizingMask:CPViewWidthSizable|CPViewHeightSizable];
    [contentView addSubview:webView];
    [newWindow setTitle:[issue objectForKey:"title"]];

    [newWindow orderFront:self];
    [newWindow setDelegate:webView];

    [webView setIssue:issue];
    [webView setRepo:repo];
    [webView loadIssue];
}

- (@action)closeIssue:(id)sender
{
    var issue = [self selectedIssue];
    if (issue && [issue objectForKey:"state"] === "open")
    {
        [[GithubAPIController sharedController] closeIssue:issue repository:repo callback:nil];
    }
}

- (@action)reopenIssue:(id)sender
{
    var issue = [self selectedIssue];
    if (issue && [issue objectForKey:"state"] === "closed")
    {
        [[GithubAPIController sharedController] reopenIssue:issue repository:repo callback:nil];
    }
}

- (@action)comment:(id)sender
{
    var issue = [self selectedIssue];
    if (!issue)
        return;

    // FIXME
    var webFrame = [issueWebView._frameView frame];
    [issueWebView._frameView scrollPoint:CGPointMake(0, CGRectGetMaxY(webFrame))];

    var scriptObject = [issueWebView windowScriptObject];
    [scriptObject callWebScriptMethod:"showCommentForm" withArguments:nil];
}

- (@action)newIssue:(id)sender
{
    var controller = [[NewIssueWindowController alloc] initWithWindowCibName:"NewIssueWindow"];
    [controller showWindow:self];
    [controller setRepos:[[[CPApp delegate] reposController] sortedRepos]];
    [controller selectRepo:repo];
    [controller setDelegate:self];
}

- (void)newIssueWindowController:(CPWindowController)aController didAddIssue:(id)anIssue toRepo:(id)aRepo
{
    if (aRepo === repo)
        [issuesTableView reloadData];
}

- (@action)reload:(id)sender
{
    delete repo.openIssues;
    delete repo.closedIssues;
    [self loadIssues];
}

- (void)loadIssues
{
    if (repo.openIssues && repo.closedIssues)
        return;

    [[GithubAPIController sharedController] loadIssuesForRepository:repo callback:function(success)
    {
        [issuesTableView reloadData];
        [self showView:nil];
    }];
}

- (void)showView:(CPView)aView
{
    [displayedView removeFromSuperview];

    if (aView)
    {
        [aView setFrame:[detailParentView bounds]];
        [detailParentView addSubview:aView];
    }

    displayedView = aView;
}

- (void)setRepo:(id)aRepo
{
    if (repo === aRepo)
        return;

    repo = aRepo;

    if (repo)
    {
        if (repo.openIssues && repo.closedIssues)
        {
            [issuesTableView selectRowIndexes:[CPIndexSet indexSet] byExtendingSelection:NO];
            [self showView:nil];
            [self tableViewSelectionDidChange:nil];
        }
        else
        {
            [self showView:loadingIssuesView];
            [self loadIssues];
        }
    }
    else
        [self showView:noRepoView];

    [issuesTableView reloadData];
    [[[[CPApp delegate] mainWindow] toolbar] validateVisibleItems];
}

- (void)moveIssueWithNumber:(int)issueNumber toPosition:(int)newPosition
{
    // we can assume the we're not filtering issues

    // find the issue
    var item = nil;

    for (var i = 0; i < [repo[displayedIssuesKey] count]; i++)
    {
        item = repo[displayedIssuesKey][i];

        if ([item valueForKey:@"number"] === issueNumber)
            break;
    }

    if (!item)
        return;

    [[GithubAPIController sharedController] setPositionForIssue:item inRepository:repo to:newPosition callback:function(success)
    {
        //[issuesTableView reloadData];
        // FIX ME: this is returning false... XD
    }];

   
}

- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{
    var item = [self selectedIssue];

    [issueWebView loadHTMLString:""];

    if (item)
    {
        [issueWebView setIssue:item];
        [issueWebView setRepo:repo];
        [issueWebView loadIssue];

        [CPApp setArguments:[repo.owner, repo.name, [item objectForKey:"number"]]];
    }

    [[[[CPApp delegate] mainWindow] toolbar] validateVisibleItems];
}

- (id)tableView:(CPTableView)aTableView objectValueForTableColumn:(int)aColumn row:(int)aRow
{
    var columnIdentifier = [aColumn identifier],
        issue = [(filteredIssues || repo[displayedIssuesKey]) objectAtIndex:aRow],
        value = [issue objectForKey:columnIdentifier];

    //special cases
    if(columnIdentifier === @"created_at" || columnIdentifier === @"updated_at")
        value = [CPDate simpleDate:value];
    else if (columnIdentifier === @"votes" && value === 0)
        value = @"-";
    else if (columnIdentifier === @"position") 
    {
        var min = repo[displayedIssuesKey+"Min"],
            max = repo[displayedIssuesKey+"Max"];
        value = (max - value)/(max - min);
    }
    return value;
}

- (int)numberOfRowsInTableView:(CPTableView)aTableView
{
    if (filteredIssues)
        return filteredIssues.length;
    else if (repo && repo[displayedIssuesKey])
        return repo[displayedIssuesKey].length;
    else
        return 0;
}

- (void)tableView:(CPTableView)aTableView sortDescriptorsDidChange:(CPArray)oldDescriptors
{   
    var newDescriptors = [aTableView sortDescriptors],
        issues = filteredIssues || repo[displayedIssuesKey],
        currentIssue = issues[[aTableView selectedRow]];

    [issues sortUsingDescriptors:newDescriptors];
    [aTableView reloadData];

    var newIndex = [issues indexOfObject:currentIssue];
    if (newIndex >= 0)
        [aTableView selectRowIndexes:[CPIndexSet indexSetWithIndex:newIndex] byExtendingSelection:NO];
}

- (BOOL)tableView:(CPTableView)aTableView writeRowsWithIndexes:(CPIndexSet)rowIndexes toPasteboard:(CPPasteboard)pboard
{
    // early return because it doesn't look like the GitHub API supports repositioning yet.
    return NO;

    // we can only reposition issue if they're sorted by position and we're not filtering them
    if (![[aTableView sortDescriptors] count] || [[aTableView sortDescriptors][0] key] !== @"position" || [filteredIssues count])
        return NO;

    [pboard declareTypes:[CPArray arrayWithObject:@"RepositionIssueDragType"] owner:self];

    // give the issue number to the pasteboard.
    var item = [[repo[displayedIssuesKey] objectAtIndex:[rowIndexes firstIndex]] valueForKey:@"number"],
        encodedData = [CPKeyedArchiver archivedDataWithRootObject:item];
    [pboard setData:encodedData forType:@"RepositionIssueDragType"];

    return YES;
}

- (CPDragOperation)tableView:(CPTableView)aTableView 
                   validateDrop:(id)info 
                   proposedRow:(CPInteger)row 
                   proposedDropOperation:(CPTableViewDropOperation)operation
{
    if([[[info draggingPasteboard] types] containsObject:@"RepositionIssueDragType"])
    {
        [aTableView setDropRow:row dropOperation:CPTableViewDropAbove];
        return CPDragOperationMove;
    }

    return CPDragOperationNone;
}

- (BOOL)tableView:(CPTableView)aTableView acceptDrop:(id)info row:(int)row dropOperation:(CPTableViewDropOperation)operation
{
    if([[[info draggingPasteboard] types] containsObject:@"RepositionIssueDragType"])
    {

        var pboard = [info draggingPasteboard],
            dragData = [pboard dataForType:@"RepositionIssueDragType"];

            dragData = [CPKeyedUnarchiver unarchiveObjectWithData:dragData];

        [self moveIssueWithNumber:dragData toPosition:row];

        return YES;
    }

    return NO;
}


- (void)searchFieldDidChange:(id)sender
{
    if (sender)
        searchString = [sender stringValue];

    if (searchString)
    {
        [self showFilterBar];
        filteredIssues = [];

        var theIssues = repo[displayedIssuesKey];
        for (var i = 0, count = [theIssues count]; i < count; i++)
        {
            var item = [theIssues objectAtIndex:i];

            if ((searchFilter === IssuesFilterAll || searchFilter === IssuesFilterTitle) && 
                [[item valueForKey:@"title"] lowercaseString].match(searchString))
            {
                [filteredIssues addObject:[theIssues objectAtIndex:i]];
                continue;
            }

            if ((searchFilter === IssuesFilterAll || searchFilter === IssuesFilterBody) && 
                [[item valueForKey:@"body"] lowercaseString].match(searchString))
            {
                [filteredIssues addObject:[theIssues objectAtIndex:i]];
                continue;
            }

            var tags = [[item objectForKey:@"labels"] componentsJoinedByString:@" "];
            if ((searchFilter === IssuesFilterAll || searchFilter === IssuesFilterLabels) && 
                [tags lowercaseString].match(searchString))
            {
                [filteredIssues addObject:[theIssues objectAtIndex:i]];
            }
        }

        [issuesTableView reloadData];
    }
    else
    {
        // get selected item
        var item = [self selectedIssue];

        [self hideFilterBar];
        filteredIssues = nil;
        
        // reload the table
        [issuesTableView reloadData];
        //select the index of found data to keep the correct selection
        if (item && [issuesTableView numberOfRows] > 0)
        {
            var index = [repo[displayedIssuesKey] indexOfObject:item];
            [self selectIssueAtIndex:index];
        }
    }
}

- (void)filterBarSelectionDidChange:(id)aFilterBar
{
    searchFilter = [aFilterBar selectedFilter];
    [self searchFieldDidChange:nil];
}

- (void)showFilterBar
{
    if ([filterBar superview])
        return;

    [filterBar setFrame:CGRectMake(0, 0, CGRectGetWidth([detailParentView frame]), 32)];
    [detailParentView addSubview:filterBar];

    var scrollView = [issuesTableView enclosingScrollView],
        frame = [scrollView frame];

    frame.origin.y = 32;
    frame.size.height -= 32;
    [scrollView setFrame:frame];
}

- (void)hideFilterBar
{
    if (![filterBar superview])
        return;

    [filterBar removeFromSuperview];

    var scrollView = [issuesTableView enclosingScrollView],
        frame = [scrollView frame];

    frame.origin.y = 0;
    frame.size.height += 32;
    [scrollView setFrame:frame];
}

@end

@implementation CPDictionary (JSObjects)

- (Object)toJSObject
{
    var object = {},
        keyEnumerator = [self keyEnumerator],
        key = nil;

    while((key = [keyEnumerator nextObject]) !== nil)
        object[key] = [self objectForKey:key];

    return object;
}

@end
