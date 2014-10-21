//
//  IAAverageFilter.m
//  ImageAverage
//
//  Created by jkramer on 8/21/14.
//  Copyright (c) 2014 Adobe Systems Inc. All rights reserved.
//

#import "IAAverageFilter.h"

@implementation IAAverageFilter

+ (void)initialize
{
    [CIFilter registerFilterName: @"IAAverageFilter"
                     constructor: self
                 classAttributes:
     @{kCIAttributeFilterDisplayName : @"Average Filter",
       kCIAttributeFilterCategories : @[kCICategoryCompositeOperation]}
     ];
}

static CIKernel *kernel = nil;

+ (CIFilter *)filterWithName: (NSString *)name
{
	CIFilter  *filter;
	filter = [[self alloc] init];
	return filter;
}

- (id)init
{
    if(kernel == nil)
    {
        NSBundle *bundle = [NSBundle bundleForClass: [self class]];
        NSString *code = [NSString stringWithContentsOfFile: [bundle pathForResource: @"AverageFilter" ofType: @"cikernel"]];
        NSArray *kernels = [CIKernel kernelsWithString: code];
        kernel = kernels[0];
    }
    return [super init];
}

- (CIImage *)outputImage
{
	CISampler *inputSampler = [CISampler samplerWithImage: inputImage];
	CISampler *newSampler = [CISampler samplerWithImage: inputNewImage];
 
	return [self apply:kernel
			 arguments:@[inputSampler, newSampler, inputCount]
			   options:@{kCIApplyOptionDefinition: [inputSampler definition]}];
}


@end
