Rainman
=======

This is a simple JSON-based API for tracking usage info and version info of SDKs or other software in the wild.


Usage
-----

Using whatever method you prefer, aggregate stats in a local cache in your app for a short time,
such as 5 minutes. We commonly use Redis for this. At some interval you decide (5-10 minutes),
send the batch of counts to this API.

The service aggregates counts by date/group_id/client_id/key/value, storing one row for each unique
combination of all 5. The stats can later be queried by date, group_id, client_id, key, or combinations
of all.


API
---

### `POST /report`

* date - YYYY-MM-DD
* group_id - String (can be null)
* client_id - String
* key - String
* value - String
* number - Integer

The `group_id` parameter exists to track usage based on groups.
The `client_id` parameter exists to track usage based on specific instances within a group.

The `key` and `value` parameters are what do the real work. This is best illustrated by some examples.

Tracking device versions:

* Key: `device_hardware` Value: `iPhone`
* Key: `device_os` Value: `iOS`
* Key: `device_version` Value: `7.0.2`
* Key: `device_version` Value: `7.0.1`
* Key: `device_hardware` Value: `SM-N9005`
* Key: `device_os` Value: `Android`
* Key: `device_version` Value: `2.3.6`

Tracking app versions:

* Key: `package_name` Value: `com.esri.sample-app`
* Key: `package_version` Value: `1.0.1`

After you've gathered some aggregates of these counts, send the total for each group_id/client_id/date/key/value
combination in a POST request to the `/report` endpoint. The existing count for the day will be updated
with the value of `number` provided.

### `GET /query`

* keys - List<String>, required
* value - String, optional
* group_id - String, optional
* client_id - String, optional
* from - YYYY-MM-DD, optional
* to - YYYY-MM-DD, optional

The `group_id` parameter filters by group. It can be omitted if you want global usage.

The `client_id` parameter filters by client. It can be omitted if you want group-level usage.

The `keys` parameter filters by one or more keys.

The `value` parameter can only be used for filtering if only a single key is provided.

The `from` and `to` parameters can be used to filter by a date range (inclusive).

Example queries:
* **/query?group_id=abcd&client_id=1234&key=device-os&value=android&from=2013-01-01&to=2013-12-25** android usage for a date range
* **/query?key=client-name** global client usage by day

Results will be returned in the following format, ordered by date (ascending):

```javascript
// GET /query?keys=test_key,another_test_key
{
    "data": [
        {
            "another_test_key": {
                "additional_test_value": 23
            },
            "date": "2013-12-08"
        },
        {
            "another_test_key": {
                "additional_test_value": 23,
                "another_test_value": 3,
                "test_value": 19
            },
            "date": "2013-12-09",
            "test_key": {
                "another_test_value": 9000,
                "test_value": 2
            }
        }
    ]
}
```

Android
-------

Sample code for sending tracking headers in API requests.

```java
import android.os.Build;

final Header[] headers = new Header[] {
    new BasicHeader("X-VT-Device-Manufacturer", Build.MANUFACTURER),
    new BasicHeader("X-VT-Device-Hardware", Build.HARDWARE),
    new BasicHeader("X-VT-Device-Model", Build.MODEL),
    new BasicHeader("X-VT-Device-OS", "Android"),
    new BasicHeader("X-VT-Device-Version", Build.VERSION.RELEASE),
    new BasicHeader("X-VT-Package-Name", context.getPackageName()),
    new BasicHeader("X-VT-Package-Version", getPackageVersionFromManifest(context)),
};

/**
 * Return the human readable version name from the application's AndroidManifest.xml file.
 *
 * @param context a {@link Context} object.
 * @return the application version or an empty String.
 */
public static String getPackageVersionFromManifest(Context context) {
    String version = "";
    PackageManager packageManager = context.getPackageManager();
    try {
        version = packageManager.getPackageInfo(context.getPackageName(), 0).versionName;
    } catch (PackageManager.NameNotFoundException e) {
        // Failed to get application version from manifest
    }
    return version;
}
```

iOS
---

Sample code for sending tracking headers in API requests.

```objc

- (void)addAnalyticsHeaders {
    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    NSString *appIdentifier = [bundleInfo objectForKey:(__bridge NSString *)kCFBundleIdentifierKey];
    NSString *appVersion = [bundleInfo objectForKey:(__bridge NSString *)kCFBundleVersionKey];

    [self.httpClient setDefaultHeader:@"X-VT-Device-Manufacturer" value:@"Apple"];
    [self.httpClient setDefaultHeader:@"X-VT-Device-Hardware" value:self.hardwareInfoString];
    [self.httpClient setDefaultHeader:@"X-VT-Device-OS" value:d.systemName];
    [self.httpClient setDefaultHeader:@"X-VT-Device-Version" value:[UIDevice currentDevice].systemVersion];

    [self.httpClient setDefaultHeader:@"X-VT-Package-Name" value:appIdentifier];
    [self.httpClient setDefaultHeader:@"X-VT-Package-Version" value:appVersion];
}

- (NSString *)hardwareInfoString {
    size_t size;

    // Set 'oldp' parameter to NULL to get the size of the data returned so we can allocate appropriate amount of space
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);

    // Allocate the space to store name
    char *name = malloc(size);

    // Get the platform name
    sysctlbyname("hw.machine", name, &size, NULL, 0);

    // Place name into a string
    NSString *machine = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];

    // Done with this
    free(name);

    return machine;
}
```


