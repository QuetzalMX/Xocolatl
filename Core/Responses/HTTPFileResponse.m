#import "HTTPFileResponse.h"
#import "HTTPConnection.h"
#import "HTTPLogging.h"

#import <unistd.h>
#import <fcntl.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;

#define NULL_FD  -1

@implementation HTTPFileResponse

@synthesize done;

/**
 * Converts relative URI path into full file-system path.
 **/
+ (NSString *)filePathForURI:(NSString *)path
               usingBasePath:(NSString *)documentRoot
          andValidIndexPages:(NSArray *)indexFileNames
              allowDirectory:(BOOL)allowDirectory;
{
    // Part 0: Validate document root setting.
    //
    // If there is no configured documentRoot,
    // then it makes no sense to try to return anything.
    
    if (documentRoot == nil)
    {
        HTTPLogWarn(@"%@[%p]: No configured document root", THIS_FILE, self);
        return nil;
    }
    
    // Part 1: Strip parameters from the url
    //
    // E.g.: /page.html?q=22&var=abc -> /page.html
    
    NSURL *docRoot = [NSURL fileURLWithPath:documentRoot isDirectory:YES];
    if (docRoot == nil)
    {
        HTTPLogWarn(@"%@[%p]: Document root is invalid file path", THIS_FILE, self);
        return nil;
    }
    
    NSString *relativePath = [[NSURL URLWithString:path relativeToURL:docRoot] relativePath];
    
    // Part 2: Append relative path to document root (base path)
    //
    // E.g.: relativePath="/images/icon.png"
    //       documentRoot="/Users/robbie/Sites"
    //           fullPath="/Users/robbie/Sites/images/icon.png"
    //
    // We also standardize the path.
    //
    // E.g.: "Users/robbie/Sites/images/../index.html" -> "/Users/robbie/Sites/index.html"
    
    NSString *fullPath = [[documentRoot stringByAppendingPathComponent:relativePath] stringByStandardizingPath];
    
    if ([relativePath isEqualToString:@"/"])
    {
        fullPath = [fullPath stringByAppendingString:@"/"];
    }
    
    // Part 3: Prevent serving files outside the document root.
    //
    // Sneaky requests may include ".." in the path.
    //
    // E.g.: relativePath="../Documents/TopSecret.doc"
    //       documentRoot="/Users/robbie/Sites"
    //           fullPath="/Users/robbie/Documents/TopSecret.doc"
    //
    // E.g.: relativePath="../Sites_Secret/TopSecret.doc"
    //       documentRoot="/Users/robbie/Sites"
    //           fullPath="/Users/robbie/Sites_Secret/TopSecret"
    
    if (![documentRoot hasSuffix:@"/"])
    {
        documentRoot = [documentRoot stringByAppendingString:@"/"];
    }
    
    if (![fullPath hasPrefix:documentRoot])
    {
        HTTPLogWarn(@"%@[%p]: Request for file outside document root", THIS_FILE, self);
        return nil;
    }
    
    // Part 4: Search for index page if path is pointing to a directory
    if (!allowDirectory)
    {
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir)
        {
            for (NSString *indexFileName in indexFileNames)
            {
                NSString *indexFilePath = [fullPath stringByAppendingPathComponent:indexFileName];
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:indexFilePath isDirectory:&isDir] && !isDir)
                {
                    return indexFilePath;
                }
            }
            
            // No matching index files found in directory
            return nil;
        }
    }
    
    return fullPath;
}

- (id)initWithFilePath:(NSString *)fpath forConnection:(HTTPConnection *)parent
{
	if((self = [super init]))
	{
		HTTPLogTrace();
		
		connection = parent; // Parents retain children, children do NOT retain parents
		
		fileFD = NULL_FD;
		filePath = [[fpath copy] stringByResolvingSymlinksInPath];
		if (filePath == nil)
		{
			HTTPLogWarn(@"%@: Init failed - Nil filePath", THIS_FILE);
			
			return nil;
		}
		
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
		if (fileAttributes == nil)
		{
			HTTPLogWarn(@"%@: Init failed - Unable to get file attributes. filePath: %@", THIS_FILE, filePath);
			
			return nil;
		}
		
		fileLength = (UInt64)[[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];
		fileOffset = 0;
		
		aborted = NO;
		
		// We don't bother opening the file here.
		// If this is a HEAD request we only need to know the fileLength.
	}
	return self;
}

- (void)abort
{
	HTTPLogTrace();
	
	[connection responseDidAbort:self];
	aborted = YES;
}

- (BOOL)openFile
{
	HTTPLogTrace();
	
	fileFD = open([filePath UTF8String], O_RDONLY);
	if (fileFD == NULL_FD)
	{
		HTTPLogError(@"%@[%p]: Unable to open file. filePath: %@", THIS_FILE, self, filePath);
		
		[self abort];
		return NO;
	}
	
	HTTPLogVerbose(@"%@[%p]: Open fd[%i] -> %@", THIS_FILE, self, fileFD, filePath);
	
	return YES;
}

- (BOOL)openFileIfNeeded
{
	if (aborted)
	{
		// The file operation has been aborted.
		// This could be because we failed to open the file,
		// or the reading process failed.
		return NO;
	}
	
	if (fileFD != NULL_FD)
	{
		// File has already been opened.
		return YES;
	}
	
	return [self openFile];
}

- (NSUInteger)contentLength
{
	HTTPLogTrace();
	
	return fileLength;
}

- (NSUInteger)offset
{
	HTTPLogTrace();
	
	return fileOffset;
}

- (void)setOffset:(NSUInteger)offset
{
	HTTPLogTrace2(@"%@[%p]: setOffset:%lu", THIS_FILE, self, offset);
	
	if (![self openFileIfNeeded])
	{
		// File opening failed,
		// or response has been aborted due to another error.
		return;
	}
	
	fileOffset = offset;
	
	off_t result = lseek(fileFD, (off_t)offset, SEEK_SET);
	if (result == -1)
	{
		HTTPLogError(@"%@[%p]: lseek failed - errno(%i) filePath(%@)", THIS_FILE, self, errno, filePath);
		
		[self abort];
	}
}

- (NSData *)readDataOfLength:(NSUInteger)length
{
	HTTPLogTrace2(@"%@[%p]: readDataOfLength:%lu", THIS_FILE, self, (unsigned long)length);
	
	if (![self openFileIfNeeded])
	{
		// File opening failed,
		// or response has been aborted due to another error.
		return nil;
	}
	
	// Determine how much data we should read.
	// 
	// It is OK if we ask to read more bytes than exist in the file.
	// It is NOT OK to over-allocate the buffer.
	
	UInt64 bytesLeftInFile = fileLength - fileOffset;
	
	NSUInteger bytesToRead = (NSUInteger)MIN(length, bytesLeftInFile);
	
	// Make sure buffer is big enough for read request.
	// Do not over-allocate.
	
	if (buffer == NULL || bufferSize < bytesToRead)
	{
		bufferSize = bytesToRead;
		buffer = reallocf(buffer, (size_t)bufferSize);
		
		if (buffer == NULL)
		{
			HTTPLogError(@"%@[%p]: Unable to allocate buffer", THIS_FILE, self);
			
			[self abort];
			return nil;
		}
	}
	
	// Perform the read
	
	HTTPLogVerbose(@"%@[%p]: Attempting to read %lu bytes from file", THIS_FILE, self, (unsigned long)bytesToRead);
	
	ssize_t result = read(fileFD, buffer, bytesToRead);
	
	// Check the results
	
	if (result < 0)
	{
		HTTPLogError(@"%@: Error(%i) reading file(%@)", THIS_FILE, errno, filePath);
		
		[self abort];
		return nil;
	}
	else if (result == 0)
	{
		HTTPLogError(@"%@: Read EOF on file(%@)", THIS_FILE, filePath);
		
		[self abort];
		return nil;
	}
	else // (result > 0)
	{
		HTTPLogVerbose(@"%@[%p]: Read %ld bytes from file", THIS_FILE, self, (long)result);
		
		fileOffset += result;
		
		return [NSData dataWithBytes:buffer length:result];
	}
}

- (BOOL)isDone
{
	BOOL result = (fileOffset == fileLength);
	
	HTTPLogTrace2(@"%@[%p]: isDone - %@", THIS_FILE, self, (result ? @"YES" : @"NO"));
	
	return result;
}

- (NSString *)filePath
{
	return filePath;
}

- (void)dealloc
{
	HTTPLogTrace();
	
	if (fileFD != NULL_FD)
	{
		HTTPLogVerbose(@"%@[%p]: Close fd[%i]", THIS_FILE, self, fileFD);
		
		close(fileFD);
	}
	
	if (buffer)
		free(buffer);
	
}

@end
