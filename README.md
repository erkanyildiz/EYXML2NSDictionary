# EYXML2NSDictionary
An `NSXMLParser` wrapper for converting XML to `NSDictionary` with blocks and background threading.

- Based on powerful built-in `NSXMLParser`
- Asynchronous parsing and completion block with resulting `NSDictionary` or `NSError`
- Background threading for not blocking UI while parsing
- Adding attibutes as key-value pairs after prefixing keys with `-` to prevent collision
- Converting repeating elements to proper arrays
- Handling inner texts among tags as an array using `-InnerText` key  
- Excluding comments in resulting `NSDictionary`


## Usage

- With XML data as `NSData`

```
NSData* XMLData = [Read from disk or fetch from network];

[EYXML2NSDictionary parseXMLData:XMLData completion:^(NSDictionary* dict, NSError* error)
{
    if (!error)
        NSLog(@"Result: %@", dict);
    else
        NSLog(@"Error: %@", error);
}];
    
```
    
- With XML string as `NSString`

```

NSString* XMLString = @""
"<message>"
"    <to>A</to>"
"    <from>B</from>"
"    <title >Fourth Title</title>"
"    <body>"
"          This is meessage body."
"        <attachment>Attachment 1</attachment>"
"    </body>"
"</message>";

[EYXML2NSDictionary parseXMLString:XMLString completion:^(NSDictionary* dict, NSError* error)
{
    if (!error)
        NSLog(@"Result: %@", dict);
    else
        NSLog(@"Error: %@", error);
}];
```

## Examples
### 1

- Input

```
<message>
    <to>A</to>
    <from>B</from>
    <title anAttribute = 'a1' anotherAttribute = 'a2'>First Title</title>
    <title anAttribute = 'b1' anotherAttribute = 'b2'>Second Title</title>
    <title >Third Title</title>
    <title >Fourth Title</title>
    <body>
          This is meessage body.
        <attachment>Attachment 1</attachment>
        <attachment>Attachment 2</attachment>
       Yet more text is here.
        <attachment>Attachment 3</attachment>
       This is the last text.
    </body>
</message>;
```

- Output

```
{
  "message": {
    "body": {
      "attachment": [
        "Attachment 1",
        "Attachment 2",
        "Attachment 3"
      ],
      "-InnerText": [
        "This is meessage body.",
        "Yet more text is here.",
        "This is the last text."
      ]
    },
    "to": "A",
    "title": [
      {
        "-anAttribute": "a1",
        "-InnerText": "First Title",
        "-anotherAttribute": "a2"
      },
      {
        "-anAttribute": "b1",
        "-InnerText": "Second Title",
        "-anotherAttribute": "b2"
      },
      "Third Title",
      "Fourth Title"
    ],
    "from": "B"
  }
}
```

### 2

- Input

```
<a attr="A">
    <b attr1="B1-1" attr2="B1-2">BBBBB 1</b>
    XXXXX    
    <b attr="B2">
        BBBBB 2_0
        <c attr="C1">CCCCC 1</c>
        BBBBB 2_1 
        <c attr="C2">
            CCCCC 2
            <d>
                DDDDD 1
                <e>
                    EEEEE 1
                    <f>FFFFF</f>
                    EEEEE 2
                </e>
                DDDDD 2
            </d></c>
        <c attr="C3">CCCCC 3</c>
        BBBBB 2_2
    </b>
    YYYYY
    <b>BBBBB 3</b>
    ZZZZZ
</a>
```

- Output

```
{
  "a": {
    "-attr": "A",
    "b": [
      {
        "-attr2": "B1-2",
        "-attr1": "B1-1",
        "-InnerText": "BBBBB 1"
      },
      {
        "-attr": "B2",
        "-InnerText": [
          "BBBBB 2_0",
          "BBBBB 2_1",
          "BBBBB 2_2"
        ],
        "c": [
          {
            "-attr": "C1",
            "-InnerText": "CCCCC 1"
          },
          {
            "-attr": "C2",
            "-InnerText": "CCCCC 2",
            "d": {
              "e": {
                "f": "FFFFF",
                "-InnerText": [
                  "EEEEE 1",
                  "EEEEE 2"
                ]
              },
              "-InnerText": [
                "DDDDD 1",
                "DDDDD 2"
              ]
            }
          },
          {
            "-attr": "C3",
            "-InnerText": "CCCCC 3"
          }
        ]
      },
      "BBBBB 3"
    ],
    "-InnerText": [
      "XXXXX",
      "YYYYY",
      "ZZZZZ"
    ]
  }
}
```
