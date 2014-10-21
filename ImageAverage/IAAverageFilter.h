//
//  IAAverageFilter.h
//  ImageAverage
//
//  Created by jkramer on 8/21/14.
//  Copyright (c) 2014 Adobe Systems Inc. All rights reserved.
//

#import <QuartzCore/CoreImage.h>

@interface IAAverageFilter : CIFilter {
    CIImage *inputImage;
    CIImage *inputNewImage;
    NSNumber *inputCount;
}


@end
