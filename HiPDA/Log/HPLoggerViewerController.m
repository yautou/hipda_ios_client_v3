//
//  HPLoggerViewerController.m
//  LoggerDemo
//

#import "HPLoggerViewerController.h"
#import "HPLoggerViewerDetailController.h"
#import <SSZipArchive/SSZipArchive.h>

@interface HPLoggerViewerController ()<UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *files;

@end

@implementation HPLoggerViewerController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"xxx"];
    
    [self refresh];
    
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
     UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share)];
    self.navigationItem.rightBarButtonItems = @[refresh, share];
}

- (void)refresh
{
    [DDLog flushLog];
    
    __block DDFileLogger *fileLogger = nil;
    [[DDLog allLoggers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:DDFileLogger.class]) {
            fileLogger = obj;
            *stop = YES;
        }
    }];
    NSArray *files = [fileLogger.logFileManager sortedLogFilePaths];
    self.files = files;
    
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.files.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"xxx" forIndexPath:indexPath];
    
    NSString *text = [[self.files[indexPath.row] componentsSeparatedByString:@"/"] lastObject];
    
    text = [text stringByReplacingCharactersInRange:NSMakeRange(0, [text rangeOfString:@" "].location) withString:@""];
    cell.textLabel.text = text;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *path = self.files[indexPath.row];
    HPLoggerViewerDetailController *vc = [HPLoggerViewerDetailController new];
    vc.path = path;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark -
- (void)share
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [DDLog flushLog];
        
        __block DDFileLogger *fileLogger = nil;
        [[DDLog allLoggers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:DDFileLogger.class]) {
                fileLogger = obj;
                *stop = YES;
            }
        }];
        NSArray *files = [fileLogger.logFileManager sortedLogFilePaths];
        
        NSString *docsdir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        NSString *path = [docsdir stringByAppendingString:@"/LogZip"];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd";
        NSString *suffix = [formatter stringFromDate:[NSDate date]];
        
        NSString *zipPath = [NSString stringWithFormat:@"%@/log_%@.zip", path, suffix];
        BOOL success = [SSZipArchive createZipFileAtPath:zipPath withFilesAtPaths:files];
        NSAssert(success, @"zip file error");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *activityItems = [@[] mutableCopy];
            [activityItems addObject: [NSURL fileURLWithPath:zipPath]];
            
            UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            
            [activityViewController setCompletionHandler:^(NSString *activityType, BOOL completed) {
                NSLog(@"activityType %@, completed %d", activityType, completed);
            }];
            
            [self presentViewController:activityViewController animated:YES completion:nil];;
        });
    });
}

@end
