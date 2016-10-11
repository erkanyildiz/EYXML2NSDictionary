// erkanyildiz
// 20161011-1321+0900
//
// EYXML2NSDictionary.m

#import "EYXML2NSDictionary.h"

NSString * const kEYXML2NSDictionaryInnerTextKey = @"-InnerText";
NSString * const kEYXML2NSDictionaryAttributeKeyPrefix = @"-";

@interface EYXML2NSDictionary()
@property (nonatomic, strong) NSMutableArray* stack;
@property (nonatomic, strong) NSMutableString* innerText;
@property (nonatomic, strong) NSError* error;
@end

@implementation EYXML2NSDictionary

#pragma mark - Init

static EYXML2NSDictionary *sharedOne = nil;

- (instancetype)init
{
    if(self = [super init])
    {
        // Create stack with root dictionary at the bottom
        self.stack = @[NSMutableDictionary.new].mutableCopy;
        self.innerText = NSMutableString.new;
    }

    return self;
}

#pragma mark - Public methods

+ (void)parseXMLData:(NSData *)data completion:(void (^)(NSDictionary * dict, NSError * error))completion
{
    NSAssert(completion != nil, @"[EYXML2NSDictionaryException] completion block can not be nil");

    EYXML2NSDictionary* p = EYXML2NSDictionary.new;
    NSXMLParser *parser = [NSXMLParser.alloc initWithData:data];
    parser.delegate = p;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        BOOL isParsingSuccessful = [parser parse];

        if(isParsingSuccessful)
        {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(p.stack.firstObject, nil); });
        }
        else
        {
            if(!p.error) p.error = [NSError errorWithDomain:@"EYXML2NSDictionaryErrorDomain" code:0 userInfo:@{NSLocalizedDescriptionKey:@"Parsing operation aborted!"}];

            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, p.error); });
        }
    });
}


+ (void)parseXMLString:(NSString *)string completion:(void (^)(NSDictionary * dict, NSError * error))completion
{
    [EYXML2NSDictionary parseXMLData:[string dataUsingEncoding:NSUTF8StringEncoding] completion:completion];
}

#pragma mark - NSXMLParserDelegate methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    //Handle inner text if exist, before proceeding with newly starting object
    self.innerText = [self.innerText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].mutableCopy;
    if(self.innerText.length > 0)
    {
        [self handleInnerTextInDictionary:self.stack.lastObject];

        self.innerText = NSMutableString.new;
    }

    // Create a new empty dictionary for newly starting object
    NSMutableDictionary* newObj = NSMutableDictionary.new;

    // Add attributes after prefixings keys to prevent collision with childs. Ex: <a this="is a"><this>collision</this></a>
    NSMutableDictionary* prefixedAttributeDict = NSMutableDictionary.new;
    for(NSString* key in attributeDict)
        prefixedAttributeDict[[kEYXML2NSDictionaryAttributeKeyPrefix stringByAppendingString:key]] = attributeDict[key];
    [newObj addEntriesFromDictionary:prefixedAttributeDict];

    // If there is no existing object, just set it. Otherwise convert it to an array
    id existingObj = self.stack.lastObject[elementName];
    if(!existingObj)
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

    //Handle inner text if exist
    self.innerText = [self.innerText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].mutableCopy;
    if(self.innerText.length > 0)
    {
        id lastObj = self.stack.lastObject[elementName];

        // If the last object is an empty dictionary, set inner text directly like {"elementName":"value"}
        if([lastObj isEqual:NSMutableDictionary.new])
            self.stack.lastObject[elementName] = self.innerText;
        else if([lastObj isKindOfClass:NSMutableDictionary.class])  // If not empty, set inner text with predefined key
            [self handleInnerTextInDictionary:lastObj];
        else if([lastObj isKindOfClass:NSMutableArray.class])       // If an array, handled it considering ended object
        {
            // If ended object is an empty dictionary, replace it directly with the inner text
            if([endedObj isEqual:NSMutableDictionary.new])
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


- (void)handleInnerTextInDictionary:(NSMutableDictionary *)mutableDict
{
    // If there is no existing inner text, just set it. Otherwise convert it to an array
    id existingInnerText = mutableDict[kEYXML2NSDictionaryInnerTextKey];
    if(!existingInnerText)
        mutableDict[kEYXML2NSDictionaryInnerTextKey] = self.innerText;
    else if ([existingInnerText isKindOfClass:NSMutableArray.class])
        [existingInnerText addObject:self.innerText];
    else
        mutableDict[kEYXML2NSDictionaryInnerTextKey] = @[existingInnerText, self.innerText].mutableCopy;
}
@end
