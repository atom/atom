// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_url.h"
#include "testing/gtest/include/gtest/gtest.h"

TEST(URLTest, CreateURL) {
  // Create the URL using the spec.
  {
    CefURLParts parts;
    CefString url;
    CefString(&parts.spec).FromASCII(
        "http://user:pass@www.example.com:88/path/to.html?foo=test&bar=test2");
    ASSERT_TRUE(CefCreateURL(parts, url));
    ASSERT_EQ(url,
        "http://user:pass@www.example.com:88/path/to.html?foo=test&bar=test2");
  }

  // Test that scheme and host are required.
  {
    CefURLParts parts;
    CefString url;
    CefString(&parts.scheme).FromASCII("http");
    ASSERT_FALSE(CefCreateURL(parts, url));
  }
  {
    CefURLParts parts;
    CefString url;
    CefString(&parts.host).FromASCII("www.example.com");
    ASSERT_FALSE(CefCreateURL(parts, url));
  }

  // Create the URL using scheme and host.
  {
    CefURLParts parts;
    CefString url;
    CefString(&parts.scheme).FromASCII("http");
    CefString(&parts.host).FromASCII("www.example.com");
    ASSERT_TRUE(CefCreateURL(parts, url));
    ASSERT_EQ(url, "http://www.example.com/");
  }

  // Create the URL using scheme, host and path.
  {
    CefURLParts parts;
    CefString url;
    CefString(&parts.scheme).FromASCII("http");
    CefString(&parts.host).FromASCII("www.example.com");
    CefString(&parts.path).FromASCII("/path/to.html");
    ASSERT_TRUE(CefCreateURL(parts, url));
    ASSERT_EQ(url, "http://www.example.com/path/to.html");
  }

  // Create the URL using scheme, host, path and query.
  {
    CefURLParts parts;
    CefString url;
    CefString(&parts.scheme).FromASCII("http");
    CefString(&parts.host).FromASCII("www.example.com");
    CefString(&parts.path).FromASCII("/path/to.html");
    CefString(&parts.query).FromASCII("foo=test&bar=test2");
    ASSERT_TRUE(CefCreateURL(parts, url));
    ASSERT_EQ(url, "http://www.example.com/path/to.html?foo=test&bar=test2");
  }

  // Create the URL using all the various components.
  {
    CefURLParts parts;
    CefString url;
    CefString(&parts.scheme).FromASCII("http");
    CefString(&parts.username).FromASCII("user");
    CefString(&parts.password).FromASCII("pass");
    CefString(&parts.host).FromASCII("www.example.com");
    CefString(&parts.port).FromASCII("88");
    CefString(&parts.path).FromASCII("/path/to.html");
    CefString(&parts.query).FromASCII("foo=test&bar=test2");
    ASSERT_TRUE(CefCreateURL(parts, url));
    ASSERT_EQ(url,
        "http://user:pass@www.example.com:88/path/to.html?foo=test&bar=test2");
  }
}

TEST(URLTest, ParseURL) {
  // Parse the URL using scheme and host.
  {
    CefURLParts parts;
    CefString url;
    url.FromASCII("http://www.example.com");
    ASSERT_TRUE(CefParseURL(url, parts));

    CefString spec(&parts.spec);
    ASSERT_EQ(spec, "http://www.example.com/");
    ASSERT_EQ(parts.username.length, (size_t)0);
    ASSERT_EQ(parts.password.length, (size_t)0);
    CefString scheme(&parts.scheme);
    ASSERT_EQ(scheme, "http");
    CefString host(&parts.host);
    ASSERT_EQ(host, "www.example.com");
    ASSERT_EQ(parts.port.length, (size_t)0);
    CefString path(&parts.path);
    ASSERT_EQ(path, "/");
    ASSERT_EQ(parts.query.length, (size_t)0);
  }

  // Parse the URL using scheme, host and path.
  {
    CefURLParts parts;
    CefString url;
    url.FromASCII("http://www.example.com/path/to.html");
    ASSERT_TRUE(CefParseURL(url, parts));

    CefString spec(&parts.spec);
    ASSERT_EQ(spec, "http://www.example.com/path/to.html");
    ASSERT_EQ(parts.username.length, (size_t)0);
    ASSERT_EQ(parts.password.length, (size_t)0);
    CefString scheme(&parts.scheme);
    ASSERT_EQ(scheme, "http");
    CefString host(&parts.host);
    ASSERT_EQ(host, "www.example.com");
    ASSERT_EQ(parts.port.length, (size_t)0);
    CefString path(&parts.path);
    ASSERT_EQ(path, "/path/to.html");
    ASSERT_EQ(parts.query.length, (size_t)0);
  }

  // Parse the URL using scheme, host, path and query.
  {
    CefURLParts parts;
    CefString url;
    url.FromASCII("http://www.example.com/path/to.html?foo=test&bar=test2");
    ASSERT_TRUE(CefParseURL(url, parts));

    CefString spec(&parts.spec);
    ASSERT_EQ(spec, "http://www.example.com/path/to.html?foo=test&bar=test2");
    ASSERT_EQ(parts.username.length, (size_t)0);
    ASSERT_EQ(parts.password.length, (size_t)0);
    CefString scheme(&parts.scheme);
    ASSERT_EQ(scheme, "http");
    CefString host(&parts.host);
    ASSERT_EQ(host, "www.example.com");
    ASSERT_EQ(parts.port.length, (size_t)0);
    CefString path(&parts.path);
    ASSERT_EQ(path, "/path/to.html");
    CefString query(&parts.query);
    ASSERT_EQ(query, "foo=test&bar=test2");
  }

  // Parse the URL using all the various components.
  {
    CefURLParts parts;
    CefString url;
    url.FromASCII(
        "http://user:pass@www.example.com:88/path/to.html?foo=test&bar=test2");
    ASSERT_TRUE(CefParseURL(url, parts));

    CefString spec(&parts.spec);
    ASSERT_EQ(spec,
        "http://user:pass@www.example.com:88/path/to.html?foo=test&bar=test2");
    CefString scheme(&parts.scheme);
    ASSERT_EQ(scheme, "http");
    CefString username(&parts.username);
    ASSERT_EQ(username, "user");
    CefString password(&parts.password);
    ASSERT_EQ(password, "pass");
    CefString host(&parts.host);
    ASSERT_EQ(host, "www.example.com");
    CefString port(&parts.port);
    ASSERT_EQ(port, "88");
    CefString path(&parts.path);
    ASSERT_EQ(path, "/path/to.html");
    CefString query(&parts.query);
    ASSERT_EQ(query, "foo=test&bar=test2");
  }

  // Parse an invalid URL.
  {
    CefURLParts parts;
    CefString url;
    url.FromASCII("www.example.com");
    ASSERT_FALSE(CefParseURL(url, parts));
  }
}
