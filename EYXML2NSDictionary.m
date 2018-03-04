// erkanyildiz
// 20180305-0051+0900
//
// EYXML2NSDictionary.m

#import "EYXML2NSDictionary.h"

@interface EYXML2NSDictionary()

@property (nonatomic, strong) NSMutableArray* stack;
@property (nonatomic, strong) NSMutableString* innerText;
@property (nonatomic, strong) NSError* error;
@property (nonatomic, strong) EYXML2NSDictionary* keeper;

@end


@implementation EYXML2NSDictionary

#pragma mark - Init

- (instancetype)init
{
    if (self = [super init])
    {
        self.stack = @[NSMutableDictionary.new].mutableCopy;  // Create stack with root dictionary at the bottom
        self.innerText = NSMutableString.new;
        self.keeper = self;  // Make sure the instance created in class method lives long enough
    }

    return self;
}


#pragma mark - Public methods


+ (void)parseXMLData:(NSData *)data completion:(void (^)(NSDictionary* dict, NSError* error))completion
{
    if (!completion)
        return;

    if (!data)
    {
        NSError* error = [EYXML2NSDictionary error:EYXML2NSDictionaryErrorNilData];
        onMainThread(^{ completion(nil, error); });
        return;
    }

    EYXML2NSDictionary* anInstance = EYXML2NSDictionary.new;
    NSXMLParser* parser = [NSXMLParser.alloc initWithData:data];
    parser.delegate = anInstance;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        BOOL isParsingSuccessful = [parser parse];

        if (isParsingSuccessful)
        {
            NSDictionary* result = [anInstance.stack.firstObject copy];
            onMainThread(^{ completion(result, nil); });
        }
        else
        {
            NSError* error = anInstance.error ?: [EYXML2NSDictionary error:EYXML2NSDictionaryErrorParsingFailed];
            onMainThread(^{ completion(nil, error); });
        }

        anInstance.keeper = nil;
    });
}


+ (void)parseXMLString:(NSString *)string completion:(void (^)(NSDictionary* dict, NSError* error))completion
{
    [EYXML2NSDictionary parseXMLData:[string dataUsingEncoding:NSUTF8StringEncoding] completion:completion];
}


#pragma mark - NSXMLParserDelegate methods


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    // Handle inner text if exist, before proceeding with newly starting object
    self.innerText = [self.innerText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].mutableCopy;
    if (self.innerText.length > 0)
    {
        [self handleInnerTextInDictionary:self.stack.lastObject];

        self.innerText = NSMutableString.new;
    }

    // Create a new empty dictionary for newly starting object
    NSMutableDictionary* newObj = NSMutableDictionary.new;

    // Add attributes using prefixed keys to prevent collision with children. Ex: <a this="is a"><this>collision</this></a>
    NSString* const kEYXML2NSDictionaryAttributeKeyPrefix = @"-";

    NSMutableDictionary* prefixedAttributeDict = NSMutableDictionary.new;
    for(NSString* key in attributeDict)
        prefixedAttributeDict[[kEYXML2NSDictionaryAttributeKeyPrefix stringByAppendingString:key]] = attributeDict[key];
    [newObj addEntriesFromDictionary:prefixedAttributeDict];

    // If there is no existing object, just set it. Otherwise convert it to an array
    id existingObj = self.stack.lastObject[elementName];
    if (!existingObj)
        self.stack.lastObject[elementName] = newObj;
    else if ([existingObj isKindOfClass:NSMutableArray.class])
        [existingObj addObject:newObj];
    else
        self.stack.lastObject[elementName] = @[existingObj, newObj].mutableCopy;

    // Push the new value to stack
    [self.stack addObject:newObj];
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    // Accumulate inner text
    [self.innerText appendString:string];
}


- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    // Keep reference to just ended object
    id endedObj = self.stack.lastObject;

    // Pop the stack
    [self.stack removeLastObject];

    // Handle inner text if exist
    self.innerText = [self.innerText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].mutableCopy;
    if (self.innerText.length > 0)
    {
        id lastObj = self.stack.lastObject[elementName];

        // If the last object is an empty dictionary, set inner text directly like {"elementName":"value"}
        if ([lastObj isEqual:NSMutableDictionary.new])
            self.stack.lastObject[elementName] = self.innerText;
        else if ([lastObj isKindOfClass:NSMutableDictionary.class])  // If not empty, set inner text with predefined key
            [self handleInnerTextInDictionary:lastObj];
        else if ([lastObj isKindOfClass:NSMutableArray.class])       // If an array, handled it considering ended object
        {
            // If ended object is an empty dictionary, replace it directly with the inner text
            if ([endedObj isEqual:NSMutableDictionary.new])
            {
                [lastObj addObject:self.innerText];
                [lastObj removeObject:endedObj];
            }
            else    // If not empty, set inner text with predefined key
                [self handleInnerTextInDictionary:endedObj];
        }

        self.innerText = NSMutableString.new;
    }
}


- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    self.error = parseError;
}


#pragma mark -


- (void)handleInnerTextInDictionary:(NSMutableDictionary *)mutableDict
{
    // If there is no existing inner text, just set it. Otherwise convert it to an array
    NSString* const kEYXML2NSDictionaryInnerTextKey = @"-InnerText";
    id existingInnerText = mutableDict[kEYXML2NSDictionaryInnerTextKey];

    if (!existingInnerText)
        mutableDict[kEYXML2NSDictionaryInnerTextKey] = self.innerText;
    else if ([existingInnerText isKindOfClass:NSMutableArray.class])
        [existingInnerText addObject:self.innerText];
    else
        mutableDict[kEYXML2NSDictionaryInnerTextKey] = @[existingInnerText, self.innerText].mutableCopy;
}


NSErrorDomain const EYXML2NSDictionaryErrorDomain = @"EYXML2NSDictionaryErrorDomain";

+ (NSError *)error:(NSInteger)errorCode
{
    NSMutableDictionary* userInfo = NSMutableDictionary.new;

    switch (errorCode)
    {
        case EYXML2NSDictionaryErrorNilData:
        {
            userInfo[NSLocalizedDescriptionKey] = @"Data to be parsed is nil.";
        }break;

        case EYXML2NSDictionaryErrorParsingFailed:
        {
            userInfo[NSLocalizedDescriptionKey] = @"Parsing operation failed.";
        }break;

        default:
            userInfo = nil;
        break;
    }

    return [NSError errorWithDomain:EYXML2NSDictionaryErrorDomain code:errorCode userInfo:userInfo.copy];
}


void onMainThread(void (^block)(void))
{
    dispatch_async(dispatch_get_main_queue(), block);
}

@end
