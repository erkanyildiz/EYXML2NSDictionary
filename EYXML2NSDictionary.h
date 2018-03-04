// erkanyildiz
// 20180305-0051+0900
//
// EYXML2NSDictionary.h

#import <Foundation/Foundation.h>

extern NSErrorDomain const EYXML2NSDictionaryErrorDomain;

NS_ENUM(NSInteger)
{
    EYXML2NSDictionaryErrorNilData = 1001,
    EYXML2NSDictionaryErrorParsingFailed = 1002
};

@interface EYXML2NSDictionary : NSObject <NSXMLParserDelegate>

/**
 * Parses the given XML data on a background thread and executes completion block with the resulting NSDictionary object on main thread.
 * @discussion It uses built-in NSXMLParser to traverse through all the elements in a background thread and piles them up in an NSDictionary. Attributes on elements are also added as key-value pairs after being prefixed.
 * If the given XML data can not be parsed, the completion block will be executed on main thread with the @c error object and the resulting NSDictionary @c dict will be nil.
 * If everything goes fine, the completion block will be executed on main thread with the resulting NSDictionary @c dict and the @c error object will be nil.
 @param data XML data to be parsed
 @param completion Completion block to be executed on main thread when parsing is completed, either with resulting @c dict object or @c error.
 */
+ (void)parseXMLData:(NSData *)data completion:(void (^)(NSDictionary* dict, NSError* error))completion;

/**
 * Parses the given XML string on a background thread and executes completion block with the resulting NSDictionary object on main thread.
 * @discussion It is just a convenience method that uses @c parseXMLData:completion method after converting XML string to data.
 @param string XML string to be parsed
 @param completion Completion block to be executed on main thread when parsing is completed, either with resulting @c dict object or @c error.
 */
+ (void)parseXMLString:(NSString *)string completion:(void (^)(NSDictionary* dict, NSError* error))completion;
@end
