//
//  AppDelegate.m
//  ImageAverage
//
//  Created by jkramer on 8/21/14.
//  Copyright (c) 2014 Adobe Systems Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "IAAverageFilter.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSImageView *resultImageView;
@property (weak) IBOutlet NSImageView *resultAverageImageView;
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *rgbLabel;
@property (strong) NSArray *images;
@property (strong) NSImage *averageImage;
@property (strong) NSImage *averageColor;
@property (assign) uint8_t *averageColorRGB;

@property (strong) NSOperationQueue *queue;

@end

@implementation AppDelegate
            
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self.tableView registerForDraggedTypes:@[(NSString *)kUTTypeFileURL]];
	self.queue = [[NSOperationQueue alloc] init];
	self.progressIndicator.hidden = YES;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (NSArray *)imageURLsFromDraggingInfo:(id<NSDraggingInfo>)info {
	//get the file URLs from the pasteboard
	NSPasteboard* pb = info.draggingPasteboard;
	
	NSArray* acceptedTypes = @[(NSString *)kUTTypeImage];
	
	return [pb readObjectsForClasses:[NSArray arrayWithObject:[NSURL class]]
							 options:[NSDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithBool:YES],NSPasteboardURLReadingFileURLsOnlyKey,
									  acceptedTypes, NSPasteboardURLReadingContentsConformToTypesKey,
									  nil]];

}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {

	NSArray* urls = [self imageURLsFromDraggingInfo:info];
	
	if (urls.count > 0) {
		self.progressIndicator.hidden = NO;
		[self.progressIndicator startAnimation:self];
		
		NSMutableArray *newImages = [NSMutableArray arrayWithCapacity:urls.count];
		for (NSURL *fileURL in urls) {
			[newImages addObject:[[NSImage alloc] initWithContentsOfURL:fileURL]];
		}
		
		self.images	= [NSArray arrayWithArray:newImages];
		[self.tableView reloadData];
		
		NSBlockOperation *averageImages = [NSBlockOperation blockOperationWithBlock:^{
			CIImage *averageCIImage = [self renderAverageImage];
			
			NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:averageCIImage];
			self.averageImage = [[NSImage alloc] initWithSize:rep.size];
			[self.averageImage addRepresentation:rep];
			
			CIImage *averageColorCIImage = [self renderAverageColor:averageCIImage];
			rep = [NSCIImageRep imageRepWithCIImage:averageColorCIImage];
			self.averageColor = [[NSImage alloc] initWithSize:rep.size];
			[self.averageColor addRepresentation:rep];
			
			CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
			void *bitmapData = malloc(4);
			CGContextRef context = CGBitmapContextCreate(bitmapData, 1, 1, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast);
			NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO];
			[NSGraphicsContext saveGraphicsState];
			[NSGraphicsContext setCurrentContext:nsContext];
			
			[self.averageColor drawInRect:NSMakeRect(0, 0, 1, 1)];
			
			[NSGraphicsContext restoreGraphicsState];
			
			self.averageColorRGB = CGBitmapContextGetData (context);
		}];
		
		averageImages.completionBlock = ^{
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				self.resultImageView.image = self.averageImage;
				self.resultAverageImageView.image = self.averageColor;
				self.rgbLabel.stringValue = [NSString stringWithFormat:@"R: %d, G: %d, B: %d", self.averageColorRGB[0], self.averageColorRGB[1], self.averageColorRGB[2]];
				[self.progressIndicator stopAnimation:self];
				self.progressIndicator.hidden = YES;
			}];
		};
		
		[self.queue addOperation:averageImages];
		
		return YES;
	} else {
		return NO;
	}
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
	
	NSArray* urls = [self imageURLsFromDraggingInfo:info];
	
	//only allow drag if there are images
	if(urls.count > 0) {
		return NSDragOperationMove;
	} else {
		return NSDragOperationNone;
	}
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return (self.images != nil) ? self.images.count : 0;
}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	return self.images[row];
}

- (CIImage *)renderAverageImage {
    [IAAverageFilter class];
    
    CIImage __block *result;
    CIFilter __block *currentFilter;
    
    [self.images enumerateObjectsUsingBlock:^(id nsImage, NSUInteger idx, BOOL *stop) {
		NSData *tiffRepresentation = [nsImage TIFFRepresentation];
        CIImage *image = [CIImage imageWithData:tiffRepresentation];
		if ([nsImage isFlipped]) {
			CIFilter *transform = [CIFilter filterWithName:@"CIAffineTransform"];
			[transform setValue:image forKey:@"inputImage"];
			
			NSAffineTransform *affineTransform = [NSAffineTransform transform];
			[affineTransform translateXBy:0 yBy:128];
			[affineTransform scaleXBy:1 yBy:-1];
			[transform setValue:affineTransform forKey:@"inputTransform"];
			
			image = [transform valueForKey:@"outputImage"];
		}
		
        if (idx == 0) {
            result = image;
        } else {
            if (! currentFilter) {
                currentFilter = [CIFilter filterWithName:@"IAAverageFilter" keysAndValues: kCIInputImageKey, result, nil];
            } else {
                currentFilter = [CIFilter filterWithName:@"IAAverageFilter" keysAndValues:
                                    kCIInputImageKey, [currentFilter valueForKey:kCIOutputImageKey], nil];
            }
            
            [currentFilter setValue:image forKey:@"inputNewImage"];
            [currentFilter setValue:@(idx + 1) forKey:@"inputCount"];
        }
    }];
    
    if (currentFilter) {
        result = [currentFilter valueForKey:kCIOutputImageKey];
    }
	
	return result;
}

- (CIImage *)renderAverageColor:(CIImage *)inputImage {
	//calculate average of the result
	CIFilter *imageAverage = [CIFilter filterWithName:@"CIAreaAverage"];
	[imageAverage setValue:inputImage forKey:kCIInputImageKey];
	CIVector *extent = [CIVector vectorWithX:inputImage.extent.origin.x
										   Y:inputImage.extent.origin.y
										   Z:inputImage.extent.size.width
										   W:inputImage.extent.size.height];
	[imageAverage setValue:extent forKey:kCIInputExtentKey];
	
	return [imageAverage valueForKey:kCIOutputImageKey];
}


@end
