require "formula"
class Wt < Formula
    desc "Development libraries for Wt"
    homepage "http://www.webtoolkit.eu/wt/doc/reference/html/Releasenotes.html"
    url "https://github.com/kdeforche/wt/archive/3.3.5.zip"
    version "3.3.5"
    sha256 "b6e74bf7445d32e27292e47b7bdc7cbd610c48cd244151db1bcb845361361657"

    option :universal
    option "without-docs", "Build API reference and manual pages"

    depends_on "cmake" => :build
    depends_on "pkg-config" => :build
    depends_on "boost" => :optional
    depends_on "fcgi" =>  :optional
    depends_on "openssl" => :optional
    depends_on "libpng" => :optional
    depends_on "libtiff" => :optional
    depends_on "libharu" => :optional
    depends_on "pango" => :optional
    depends_on "GraphicsMagick" => :optional
    depends_on "doxygen" => :build if build.with? "docs"
    depends_on "graphviz" => :build if build.with? "docs"

    patch :p1, :DATA

    def install
        optional_args = []
        if build.universal?
            ENV.universal_binary
            optional_args << "-DCMAKE_OSX_ARCHITECTURES=#{Hardware::CPU.universal_archs.as_cmake_arch_flags}"
        end

        witty_args = [
            # libz
            %q{-DENABLE_HTTP_WITH_ZLIB=ON},

            # openssl
            %q{-DSSL_PREFIX="/usr/local/Cellar/openssl/1.0.2e_1"},
            %q{-DENABLE_SSL=ON},

            # opengl
            %q{-DENABLE_OPENGL=ON},

            # pdf output
            %q{-DENABLE_HARU=ON},
            %q{-DENABLE_PANGO=ON},

            # sqlite
            %q{-DENABLE_SQLITE=ON},

            # mysql
            %q{-DENABLE_MYSQL=ON},

            # postgres
            %q{-DENABLE_POSTGRES=ON}
        ]

        witty_cmake_args = [
            %q{-DWT_CPP_11_MODE=-std=c++1y},

            # Unit tests
            %q{-DENABLE_LIBWTTEST=ON},

            # Database work
            %q{-DENABLE_LIBWTDBO=ON},
        ]

        cmake_compile_args = [
            #            %q{-DCMAKE_CXX_FLAGS=-stdlib=libc++},
            #            %q{-DCMAKE_EXE_LINKER_FLAGS=-stdlib=libc++},
            #            %q{-DCMAKE_MODULE_LINKER_FLAGS=-stdlib=libc++},
            %q{-DCMAKE_BUILD_TYPE=Release}
        ]

        args = [
            std_cmake_args,
            cmake_compile_args,
            witty_args,
            witty_cmake_args,
            optional_args,
        ].flatten.join(" ")

        mkdir "build" do
            File.open("/Users/me/cmake-args.txt","w"){|f| f.puts "cmake ../ #{args}" }
            interactive_shell
            system "cmake ../ #{args}"
            system "make -j5"
            system "make install"
        end
    end

    test do
        system "false"
    end
end
__END__
diff --git a/src/Wt/Http/Client b/src/Wt/Http/Client
index fbdfb45..b480586 100644
--- a/src/Wt/Http/Client
+++ b/src/Wt/Http/Client
@@ -269,7 +269,7 @@ public:
    * \sa request(), done()
    */
   bool put(const std::string& url, const Message& message);
-
+
   /*! \brief Starts a DELETE request.
    *
    * The function starts an asynchronous DELETE request, and returns
@@ -285,7 +285,22 @@ public:
    * \sa request(), done()
    */
   bool deleteRequest(const std::string& url, const Message& message);
-
+
+  /*! \brief Starts a PATCH request.
+   *
+   * The function starts an asynchronous PATCH request, and returns
+   * immediately.
+   *
+   * The function returns \c true when the PATCH request has been
+   * scheduled, and thus done() will be emitted eventually.
+   *
+   * The function returns \p false if the client could not schedule
+   * the request, for example if the \p url is invalid or if the %URL
+   * scheme is not supported.
+   *
+   * \sa request(), done()
+   */
+  bool patch(const std::string& url, const Message& message);
   /*! \brief Starts a request.
    *
    * The function starts an asynchronous HTTP request, and returns
diff --git a/src/Wt/Http/Client.C b/src/Wt/Http/Client.C
index 2eed82c..55048a7 100644
--- a/src/Wt/Http/Client.C
+++ b/src/Wt/Http/Client.C
@@ -62,25 +62,25 @@ public:

   virtual ~Impl() { }

-  void setTimeout(int timeout) {
-    timeout_ = timeout;
+  void setTimeout(int timeout) {
+    timeout_ = timeout;
   }

   void setMaximumResponseSize(std::size_t bytes) {
     maximumResponseSize_ = bytes;
   }

-  void request(const std::string& method, const std::string& auth,
+  void request(const std::string& method, const std::string& auth,
 	       const std::string& server, int port, const std::string& path,
 	       const Message& message)
   {
     std::ostream request_stream(&requestBuf_);
     request_stream << method << " " << path << " HTTP/1.1\r\n";
-    request_stream << "Host: " << server << ":"
+    request_stream << "Host: " << server << ":"
 		   << boost::lexical_cast<std::string>(port) << "\r\n";

     if (!auth.empty())
-      request_stream << "Authorization: Basic "
+      request_stream << "Authorization: Basic "
 		     << Wt::Utils::base64Encode(auth) << "\r\n";

     bool haveContentLength = false;
@@ -91,14 +91,14 @@ public:
       request_stream << h.name() << ": " << h.value() << "\r\n";
     }

-    if ((method == "POST" || method == "PUT" || method == "DELETE") &&
+    if ((method == "POST" || method == "PUT" || method == "DELETE" || method == "PATCH") &&
 	!haveContentLength)
-      request_stream << "Content-Length: " << message.body().length()
+      request_stream << "Content-Length: " << message.body().length()
 		     << "\r\n";

     request_stream << "Connection: close\r\n\r\n";

-    if (method == "POST" || method == "PUT" || method == "DELETE")
+    if (method == "POST" || method == "PUT" || method == "DELETE" || method == "PATCH")
       request_stream << message.body();

     tcp::resolver::query query(server, boost::lexical_cast<std::string>(port));
@@ -207,7 +207,7 @@ private:
       complete();
     }
   }
-
+
   void handleConnect(const boost::system::error_code& err,
 		     tcp::resolver::iterator endpoint_iterator)
   {
@@ -367,7 +367,7 @@ private:
 	  }
 	}
       }
-
+
       if (headersReceived_.isConnected()) {
 	if (server_)
 	  server_->post(sessionId_,
@@ -474,7 +474,7 @@ private:
 	  }

 	  chunkState_.parsePos = 0;
-
+
 	  break;
 	case 0:
 	  if (ch >= '0' && ch <= '9') {
@@ -509,7 +509,7 @@ private:
 	  if (chunkState_.size == 0) {
 	    chunkState_.state = ChunkState::Complete; return;
 	  }
-
+
 	  chunkState_.state = ChunkState::Data;
 	}

@@ -542,7 +542,7 @@ private:
     err_ = boost::system::errc::make_error_code
       (boost::system::errc::protocol_error);
     complete();
-  }
+  }

   void complete()
   {
@@ -788,7 +788,7 @@ bool Client::get(const std::string& url)
   return request(Get, url, Message());
 }

-bool Client::get(const std::string& url,
+bool Client::get(const std::string& url,
 		 const std::vector<Message::Header> headers)
 {
   Message m(headers);
@@ -805,6 +805,11 @@ bool Client::put(const std::string& url, const Message& message)
   return request(Put, url, message);
 }

+bool Client::patch(const std::string& url, const Message& message)
+{
+  return request(Patch, url, message);
+}
+
 bool Client::deleteRequest(const std::string& url, const Message& message)
 {
   return request(Delete, url, message);
@@ -868,9 +873,9 @@ bool Client::request(Http::Method method, const std::string& url,
 #endif // VERIFY_CERTIFICATE

     impl_.reset(new SslImpl(*ioService, verifyEnabled_,
-			    server,
-			    context,
-			    sessionId,
+			    server,
+			    context,
+			    sessionId,
 			    parsedUrl.host));
 #endif // WT_WITH_SSL

@@ -895,15 +900,15 @@ bool Client::request(Http::Method method, const std::string& url,
   impl_->setTimeout(timeout_);
   impl_->setMaximumResponseSize(maximumResponseSize_);

-  const char *methodNames_[] = { "GET", "POST", "PUT", "DELETE" };
+  const char *methodNames_[] = { "GET", "POST", "PUT", "DELETE", "PATCH" };

   LOG_DEBUG(methodNames_[method] << " " << url);

-  impl_->request(methodNames_[method],
+  impl_->request(methodNames_[method],
 		 parsedUrl.auth,
-		 parsedUrl.host,
-		 parsedUrl.port,
-		 parsedUrl.path,
+		 parsedUrl.host,
+		 parsedUrl.port,
+		 parsedUrl.path,
 		 message);

   return true;
@@ -931,21 +936,41 @@ void Client::setMaxRedirects(int maxRedirects)

 void Client::handleRedirect(Http::Method method, boost::system::error_code err, const Message& response, const Message& request)
 {
-  int status = response.status();
-  // Status codes 303 and 307 are implemented, although this should not
-  // occur when using HTTP/1.0
-  if (!err && (((status == 301 || status == 302 || status == 307) && method == Get) || status == 303)) {
-    const std::string *newUrl = response.getHeader("Location");
-    ++ redirectCount_;
-    if (newUrl) {
-      if (redirectCount_ <= maxRedirects_) {
-	get(*newUrl, request.headers());
-	return;
-      } else {
-	LOG_WARN("Redirect count of " << maxRedirects_ << " exceeded! Redirect URL: " << *newUrl);
+  if(!err)
+  {
+      // 301-303 non-HEAD request = new request with GET method
+      // 301-303 HEAD request, or 307-308 = new request with same method
+      auto http_status_code = response.status();
+      auto is_redirected_1 = (http_status_code > 300 && http_status_code < 304);
+      auto is_redirected_2 = (http_status_code > 306 && http_status_code < 309);
+      if(is_redirected_1 || is_redirected_2)
+      {
+          // Technically a 302 should not change the method, but browsers treat 302 as 303,
+          // which seems to meet most user expectations, hence emulating the behaviour should both be
+          // less suprising and encourage use of the explict 303/307 status codes.
+          Wt::Http::Method meth = ( is_redirected_2 || (is_redirected_1 && (method == Head))) ? method : Get;
+
+          const std::string *next_location = response.getHeader("Location");
+          if(!next_location)
+          {
+              LOG_WARN("No 'Location' header present after : " << maxRedirects_ << " redirects");
+              goto done;
+          }
+
+          ++ redirectCount_;
+          if (redirectCount_ > maxRedirects_)
+          {
+              LOG_WARN("Redirect count of " << maxRedirects_ << " exceeded! Redirect URL: " << *next_location);
+              goto done;
+          }
+
+          if(request(meth, *next_location, request))
+              return;
+
+          LOG_WARN("Scheduling request failed after : " << redirectCount_ << " redirects");
       }
-    }
   }
+done:
   emitDone(err, response);
 }

diff --git a/src/Wt/Http/Method b/src/Wt/Http/Method
index 26ebc22..d24ca59 100644
--- a/src/Wt/Http/Method
+++ b/src/Wt/Http/Method
@@ -16,10 +16,11 @@ namespace Wt {
  * used HTTP methods.
  */
 enum Method {
-  Get,   //!< a HTTP GET
-  Post,  //!< a HTTP POST
-  Put,   //!< a HTTP PUT
-  Delete //!< a HTTP DELETE
+  Get,    //!< a HTTP GET
+  Post,   //!< a HTTP POST
+  Put,    //!< a HTTP PUT
+  Delete, //!< a HTTP DELETE
+  Patch   //!< a HTTP PATCH
 };

   }
diff --git a/src/http/RequestHandler.C b/src/http/RequestHandler.C
index 9958b99..c855720 100644
--- a/src/http/RequestHandler.C
+++ b/src/http/RequestHandler.C
@@ -33,7 +33,7 @@ namespace {
       return b - '0';
     else if (b <= 'F')
       return (b - 'A') + 0x0A;
-    else
+    else
       return (b - 'a') + 0x0A;
   }

@@ -71,7 +71,7 @@ bool RequestHandler::matchesPath(const std::string& path,
       char next = path[prefixLength];

       if (next == '/')
-	return true;
+	return true;
       else if (matchAfterSlash) {
 	char last = prefix[prefixLength - 1];

@@ -99,11 +99,12 @@ ReplyPtr RequestHandler::handleRequest(Request& req,
       && (req.method != "OPTIONS")
       && (req.method != "POST")
       && (req.method != "PUT")
+      && (req.method != "PATCH")
       && (req.method != "DELETE"))
     return ReplyPtr(new StockReply(req, Reply::not_implemented, "", config_));

   if ((req.http_version_major != 1)
-      || (req.http_version_minor != 0
+      || (req.http_version_minor != 0
 	  && req.http_version_minor != 1))
     return ReplyPtr(new StockReply(req, Reply::not_implemented, "", config_));

@@ -214,7 +215,7 @@ bool RequestHandler::url_decode(const buffer_string& in, std::string& path,
     if (d[i] == '%') {
       if (i + 2 < len) {
 	path += fromHex(d[i + 1], d[i + 2]);
-	i += 2;
+	i += 2;
       } else
         return false;
     } else if (d[i] == '?') {
