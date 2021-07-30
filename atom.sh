README.md
.Net-Multi-Platform-App-UI-(MAUI).docx master.README.md README.md README.txt

master-cloudflare-1.1.1.1
Cloudflare DNS resolver website. 1.1.1.1 Site Cloudflare DNS Resolver and Warp Website Contributing The 1.1.1.1 documentation site is built using TypeScript, Pug templates, and Stylus stylesheets. Webpack is used to compile these assets into a build hosted on Cloudflare. A local copy can be run by first installing the project dependencies with Yarn (or NPM).

Requirements *nix or MacOS operating system Node 9.x or higher yarn install Once that command completes, start the development server.

yarn start Your console will display an IP address that serves the project.

iBSD License Copyright (c) 2015-present, Cloudflare, Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

--

Some images in this project are subject to Getty Images's distribution license. Consult https://www.gettyimages.com/eula for further information.

Working with the npm registry You can configure npm to publish packages to GitHub Packages and to use packages stored on GitHub Packages as dependencies in an npm project.

GitHub Packages available with GitHub Free, GitHub Pro, GitHub Free for organizations, GitHub Team, GitHub Enterprise Cloud, GitHub Enterprise Server, and GitHub AE.

GitHub Packages is not available for private repositories owned by accounts using legacy per-repository plans. Also, accounts using legacy per-repository plans cannot access the Container registry since these accounts are billed by repository. For more information, see "GitHub's products."

In this article Limits for published npm versions Authenticating to GitHub Packages Publishing a package Publishing multiple packages to the same repository Installing a package Further reading Limits for published npm versions If you publish over 1,000 npm package versions to GitHub Packages, you may see performance issues and timeouts occur during usage.

In the future, to improve performance of the service, you won't be able to publish more than 1,000 versions of a package on GitHub. Any versions published before hitting this limit will still be readable.

If you reach this limit, consider deleting package versions or contact Support for help. When this limit is enforced, our documentation will be updated with a way to work around this limit. For more information, see "Deleting and restoring a package" or "Contacting Support."

Authenticating to GitHub Packages You need an access token to publish, install, and delete packages.

You can use a personal access token (PAT) to authenticate to GitHub Packages or the GitHub API. When you create a personal access token, you can assign the token different scopes depending on your needs. For more information about packages-related scopes for a PAT, see "About permissions for GitHub Packages."

To authenticate to a GitHub Packages registry within a GitHub Actions workflow, you can use:

GITHUB_TOKEN to publish packages associated with the workflow repository. a PAT to install packages associated with other private repositories (which GITHUB_TOKEN can't access). For more information about GITHUB_TOKEN used in GitHub Actions workflows, see "Authentication in a workflow."

Authenticating with a personal access token You must use a personal access token with the appropriate scopes to publish and install packages in GitHub Packages. For more information, see "About GitHub Packages."

You can authenticate to GitHub Packages with npm by either editing your per-user ~/.npmrc file to include your personal access token or by logging in to npm on the command line using your username and personal access token.

To authenticate by adding your personal access token to your ~/.npmrc file, edit the ~/.npmrc file for your project to include the following line, replacing TOKEN with your personal access token. Create a new ~/.npmrc file if one doesn't exist.

//npm.pkg.github.com/:_authToken=TOKEN To authenticate by logging in to npm, use the npm login command, replacing USERNAME with your GitHub username, TOKEN with your personal access token, and PUBLIC-EMAIL-ADDRESS with your email address.

If GitHub Packages is not your default package registry for using npm and you want to use the npm audit command, we recommend you use the --scope flag with the owner of the package when you authenticate to GitHub Packages.

$ npm login --scope=@OWNER --registry=https://npm.pkg.github.com

Username: BigGuy573 Password: 50b9192d-d5b6-4920-bb49-414b89d73c7f Email: 48465089+BigGuy573@users.noreply.github.com Publishing a package Note: Package names and scopes must only use lowercase letters. By default, GitHub Packages publishes a package in the GitHub repository you specify in the name field of the package.json file. For example, you would publish a package named @my-org/test to the my-org/test GitHub repository. You can add a summary for the package listing page by including a README.md file in your package directory. For more information, see "Working with package.json" and "How to create Node.js Modules" in the npm documentation.

You can publish multiple packages to the same GitHub repository by including a URL field in the package.json file. For more information, see "Publishing multiple packages to the same repository."

You can set up the scope mapping for your project using either a local .npmrc file in the project or using the publishConfig option in the package.json. GitHub Packages only supports scoped npm packages. Scoped packages have names with the format of @owner/name. Scoped packages always begin with an @ symbol. You may need to update the name in your package.json to use the scoped name. For example, "name": "@codertocat/hello-world-npm".

After you publish a package, you can view the package on GitHub. For more information, see "Viewing packages."

Publishing a package using a local .npmrc file You can use an .npmrc file to configure the scope mapping for your project. In the .npmrc file, use the GitHub Packages URL and account owner so GitHub Packages knows where to route package requests. Using an .npmrc file prevents other developers from accidentally publishing the package to npmjs.org instead of GitHub Packages.

Authenticate to GitHub Packages. For more information, see "Authenticating to GitHub Packages."

In the same directory as your package.json file, create or edit an .npmrc file to include a line specifying GitHub Packages URL and the account owner. Replace OWNER with the name of the user or organization account that owns the repository containing your project.

@OWNER:registry=https://npm.pkg.github.com Add the .npmrc file to the repository where GitHub Packages can find your project. For more information, see "Adding a file to a repository using the command line."

Verify the name of your package in your project's package.json. The name field must contain the scope and the name of the package. For example, if your package is called "test", and you are publishing to the "My-org" GitHub organization, the name field in your package.json should be @my-org/test.

Verify the repository field in your project's package.json. The repository field must match the URL for your GitHub repository. For example, if your repository URL is github.com/my-org/test then the repository field should be git://github.com/my-org/test.git.

Publish the package:

$ npm publish Publishing a package using publishConfig in the package.json file You can use publishConfig element in the package.json file to specify the registry where you want the package published. For more information, see "publishConfig" in the npm documentation.

Edit the package.json file for your package and include a publishConfig entry.

"publishConfig": {New value { "id": "9f1571c1-3dd1-454e-b072-4efa782df1b0", "name": "Cloudflare Teams", "uid": "9f1571c1-3dd1-454e-b072-4efa782df1b0", "is_default": true, "include": [ { "any_valid_service_token": {} }{50b9192d-d5b6-4920-bb49-414b89d73c7f} ], "require": [], "exclude": [ { "email_domain": { "domain": "inves86.net; @invest86llc.net; @invest86.onmicrosoft.net; @invest86llc.cloudflareaccess.com" } } ], "created_at": "2021-07-25T18:52:25Z", "updated_at": "2021-07-25T18:52:25Z" } Meta data {} "registry":"https://npm.pkg.github.com" }, Verify the repository field in your project's package.json. The repository field must match the URL for your GitHub repository. For example, if your repository URL is github.com/my-org/test then the repository field should be git://github.com/my-org/test.git.

Publish the package:

$ npm publish Publishing multiple packages to the same repository To publish multiple packages to the same repository, you can include the URL of the GitHub repository in the repository field of the package.json file for each package.

To ensure the repository's URL is correct, replace REPOSITORY with the name of the repository containing the package you want to publish, and OWNER with the name of the user or organization account on GitHub that owns the repository.

GitHub Packages will match the repository based on the URL, instead of based on the package name.

"repository":"https://github.com/OWNER/REPOSITORY", Installing a package You can install packages from GitHub Packages by adding the packages as dependencies in the package.json file for your project. For more information on using a package.json in your project, see "Working with package.json" in the npm documentation.

By default, you can add packages from one organization. For more information, see "Installing packages from other organizations."

You also need to add the .npmrc file to your project so all requests to install packages will go through GitHub Packages. When you route all package requests through GitHub Packages, you can use both scoped and unscoped packages from npmjs.com. For more information, see "npm-scope" in the npm documentation.

Authenticate to GitHub Packages. For more information, see "Authenticating to GitHub Packages."

In the same directory as your package.json file, create or edit an .npmrc file to include a line specifying GitHub Packages URL and the account owner. Replace OWNER with the name of the user or organization account that owns the repository containing your project.

@OWNER:registry=https://npm.pkg.github.com Add the .npmrc file to the repository where GitHub Packages can find your project. For more information, see "Adding a file to a repository using the command line."

Configure package.json in your project to use the package you are installing. To add your package dependencies to the package.json file for GitHub Packages, specify the full-scoped package name, such as @my-org/server. For packages from npmjs.com, specify the full name, such as @babel/core or @lodash. For example, this following package.json uses the @octo-org/octo-app package as a dependency.

{ "name": "@my-org/server", "version": "1.0.0", "description": "Server app that uses the @octo-org/octo-app package", "main": "index.js", "author": "", "license": "MIT", "dependencies": { "@octo-org/octo-app": "1.0.0" } } Install the package.

$ npm install Installing packages from other organizations By default, you can only use GitHub Packages packages from one organization. If you'd like to route package requests to multiple organizations and users, you can add additional lines to your .npmrc file, replacing OWNER with the name of the user or organization account that owns the repository containing your project.

@OWNER:registry=https://npm.pkg.github.com @OWNER:registry=https://npm.pkg.github.com Further reading "Deleting and restoring a package"

This workflow will build a docker container, publish it to Google Container Registry, and deploy it to GKE when a release is created To configure this workflow:

Ensure that your repository contains the necessary configuration for your Google Kubernetes Engine cluster, including deployment.yml, kustomization.yml, service.yml, etc.
Set up secrets in your workspace: GKE_PROJECT with the name of the project and GKE_SA_KEY with the Base64 encoded JSON service account key (https://github.com/GoogleCloudPlatform/github-actions/tree/docs/service-account-key/setup-gcloud#inputs).
Change the values for the GKE_ZONE, GKE_CLUSTER, IMAGE, and DEPLOYMENT_NAME environment variables (below). For more support on how to run the workflow, please visit https://github.com/google-github-actions/setup-gcloud/tree/master/example-workflows/gke name: Build and Deploy to GKE
on: release: types: [created]

env: PROJECT_ID: ${{ secrets.GKE_PROJECT }} GKE_CLUSTER: cluster-1 # TODO: update to cluster name GKE_ZONE: us-central1-c # TODO: update to cluster zone DEPLOYMENT_NAME: gke-test # TODO: update to deployment name IMAGE: static-site

jobs: setup-build-publish-deploy: name: Setup, Build, Publish, and Deploy runs-on: ubuntu-latest environment: production

steps:

name: Checkout uses: actions/checkout@v2
Setup gcloud CLI
uses: google-github-actions/setup-gcloud@v0.2.0 with: service_account_key: ${{ secrets.GKE_SA_KEY }} project_id: ${{ secrets.GKE_PROJECT }}
Configure Docker to use the gcloud command-line tool as a credential
helper for authentication
run: |- gcloud --quiet auth configure-docker
Get the GKE credentials so we can deploy to the cluster
uses: google-github-actions/get-gke-credentials@v0.2.1 with: cluster_name: ${{ env.GKE_CLUSTER }} location: ${{ env.GKE_ZONE }} credentials: ${{ secrets.GKE_SA_KEY }}
Build the Docker image
name: Build run: |- docker build
--tag "gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA"
--build-arg GITHUB_SHA="$GITHUB_SHA"
--build-arg GITHUB_REF="$GITHUB_REF"
.
Push the Docker image to Google Container Registry
name: Publish run: |- docker push "gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA"
Set up kustomize
name: Set up Kustomize run: |- curl -sfLo kustomize https://github.com/kubernetes-sigs/kustomize/releases/download/v3.1.0/kustomize_3.1.0_linux_amd64 chmod u+x ./kustomize
Deploy the Docker image to the GKE cluster
name: Deploy run: |- ./kustomize edit set image gcr.io/PROJECT_ID/IMAGE:TAG=gcr.io/$PROJECT_ID/$IMAGE:$GITHUB_SHA ./kustomize build . | kubectl apply -f - kubectl rollout status deployment/$DEPLOYMENT_NAME kubectl get services -o wide Comma is not an operator in Python. Consider this session: "a" in "b", "a" (False, 'a') Since the comma is not an operator, but a separator between expressions the above is evaluated as if you had entered:
("a" in "b"), "a" not:

"a" in ("b", "a") The same is true of the various assignment operators (=, += etc). They are not truly operators but syntactic delimiters in assignment statements.

Is there an equivalent of C’s “?:” ternary operator? Yes, there is. The syntax is as follows:

[on_true] if [expression] else [on_false]

x, y = 50, 25 small = x if x < y else y Before this syntax was introduced in Python 2.5, a common idiom was to use logical operators:

[expression] and [on_true] or [on_false] However, this idiom is unsafe, as it can give wrong results when on_true has a false boolean value. Therefore, it is always better to use the ... if ... else ... form.

Is it possible to write obfuscated one-liners in Python? Yes. Usually this is done by nesting lambda within lambda. See the following three examples, due to Ulf Bartelt:

from functools import reduce

Primes < 1000 print(list(filter(None,map(lambda y:yreduce(lambda x,y:xy!=0, map(lambda x,y=y:y%x,range(2,int(pow(y,0.5)+1))),1),range(2,1000)))))

First 10 Fibonacci numbers print(list(map(lambda x,f=lambda x,f:(f(x-1,f)+f(x-2,f)) if x>1 else 1: f(x,f), range(10))))

Mandelbrot set print((lambda Ru,Ro,Iu,Io,IM,Sx,Sy:reduce(lambda x,y:x+y,map(lambda y, Iu=Iu,Io=Io,Ru=Ru,Ro=Ro,Sy=Sy,L=lambda yc,Iu=Iu,Io=Io,Ru=Ru,Ro=Ro,i=IM, Sx=Sx,Sy=Sy:reduce(lambda x,y:x+y,map(lambda x,xc=Ru,yc=yc,Ru=Ru,Ro=Ro, i=i,Sx=Sx,F=lambda xc,yc,x,y,k,f=lambda xc,yc,x,y,k,f:(k<=0)or (xx+yy

=4.0) or 1+f(xc,yc,xx-yy+xc,2.0xy+yc,k-1,f):f(xc,yc,x,y,k,f):chr( 64+F(Ru+x*(Ro-Ru)/Sx,yc,0,0,i)),range(Sx))):L(Iu+y*(Io-Iu)/Sy),range(Sy ))))(-2.1, 0.7, -1.2, 1.2, 30, 80, 24))

___ / _ / | | | lines on screen V V | |____ columns on screen | | |__________ maximum of "iterations" | |_________________ range on y axis |____________________________ range on x axis Don’t try this at home, kids!

What does the slash(/) in the parameter list of a function mean? A slash in the argument list of a function denotes that the parameters prior to it are positional-only. Positional-only parameters are the ones without an externally-usable name. Upon calling a function that accepts positional-only parameters, arguments are mapped to parameters based solely on their position. For example, divmod() is a function that accepts positional-only parameters. Its documentation looks like this:

help(divmod) Help on built-in function divmod in module builtins:

divmod(x, y, /) Return the tuple (x//y, x%y). Invariant: div*y + mod == x. The slash at the end of the parameter list means that both parameters are positional-only. Thus, calling divmod() with keyword arguments would lead to an error:

divmod(x=3, y=4) Traceback (most recent call last): File "", line 1, in TypeError: divmod() takes no keyword arguments Numbers and strings How do I specify hexadecimal and octal integers? To specify an octal digit, precede the octal value with a zero, and then a lower or uppercase “o”. For example, to set the variable “a” to the octal value “10” (8 in decimal), type:

a = 0o10 a 8 Hexadecimal is just as easy. Simply precede the hexadecimal number with a zero, and then a lower or uppercase “x”. Hexadecimal digits can be specified in lower or uppercase. For example, in the Python interpreter:

a = 0xa5 a 165 b = 0XB2 b 178 Why does -22 // 10 return -3? It’s primarily driven by the desire that i % j have the same sign as j. If you want that, and also want:

i == (i // j) * j + (i % j) then integer division has to return the floor. C also requires that identity to hold, and then compilers that truncate i // j need to make i % j have the same sign as i.

There are few real use cases for i % j when j is negative. When j is positive, there are many, and in virtually all of them it’s more useful for i % j to be >= 0. If the clock says 10 now, what did it say 200 hours ago? -190 % 12 == 2 is useful; -190 % 12 == -10 is a bug waiting to bite.

How do I convert a string to a number? For integers, use the built-in int() type constructor, e.g. int('144') == 144. Similarly, float() converts to floating-point, e.g. float('144') == 144.0.

By default, these interpret the number as decimal, so that int('0144') == 144 holds true, and int('0x144') raises ValueError. int(string, base) takes the base to convert from as a second optional argument, so int( '0x144', 16) == 324. If the base is specified as 0, the number is interpreted using Python’s rules: a leading ‘0o’ indicates octal, and ‘0x’ indicates a hex number.

Do not use the built-in function eval() if all you need is to convert strings to numbers. eval() will be significantly slower and it presents a security risk: someone could pass you a Python expression that might have unwanted side effects. For example, someone could pass import('os').system("rm -rf $HOME") which would erase your home directory.

eval() also has the effect of interpreting numbers as Python expressions, so that e.g. eval('09') gives a syntax error because Python does not allow leading ‘0’ in a decimal number (except ‘0’).

How do I convert a number to a string? To convert, e.g., the number 144 to the string ‘144’, use the built-in type constructor str(). If you want a hexadecimal or octal representation, use the built-in functions hex() or oct(). For fancy formatting, see the Formatted string literals and Format String Syntax sections, e.g. "{:04d}".format(144) yields '0144' and "{:.3f}".format(1.0/3.0) yields '0.333'.

How do I modify a string in place? You can’t, because strings are immutable. In most situations, you should simply construct a new string from the various parts you want to assemble it from. However, if you need an object with the ability to modify in-place unicode data, try using an io.StringIO object or the array module:

import io s = "Hello, world" sio = io.StringIO(s) sio.getvalue() 'Hello, world' sio.seek(7) 7 sio.write("there!") 6 sio.getvalue() 'Hello, there!'

import array a = array.array('u', s) print(a) array('u', 'Hello, world') a[0] = 'y' print(a) array('u', 'yello, world') a.tounicode() 'yello, world' How do I use strings to call functions/methods? There are various techniques.

The best is to use a dictionary that maps strings to functions. The primary advantage of this technique is that the strings do not need to match the names of the functions. This is also the primary technique used to emulate a case construct:

def a(): pass

def b(): pass

dispatch = {'go': a, 'stop': b} # Note lack of parens for funcs

dispatchget_input() # Note trailing parens to call function Use the built-in function getattr():

import foo getattr(foo, 'bar')() Note that getattr() works on any object, including classes, class instances, modules, and so on.

This is used in several places in the standard library, like this:

class Foo: def do_foo(self): ...

def do_bar(self): ... f = getattr(foo_instance, 'do_' + opname) f() Use locals() to resolve the function name:

def myFunc(): print("hello")

fname = "myFunc"

f = locals()[fname] f() Is there an equivalent to Perl’s chomp() for removing trailing newlines from strings? You can use S.rstrip("\r\n") to remove all occurrences of any line terminator from the end of the string S without removing other trailing whitespace. If the string S represents more than one line, with several empty lines at the end, the line terminators for all the blank lines will be removed:

lines = ("line 1 \r\n" ... "\r\n" ... "\r\n") lines.rstrip("\n\r") 'line 1 ' Since this is typically only desired when reading text one line at a time, using S.rstrip() this way works well.

Is there a scanf() or sscanf() equivalent? Not as such.

For simple input parsing, the easiest approach is usually to split the line into whitespace-delimited words using the split() method of string objects and then convert decimal strings to numeric values using int() or float(). split() supports an optional “sep” parameter which is useful if the line uses something other than whitespace as a separator.

For more complicated input parsing, regular expressions are more powerful than C’s sscanf() and better suited for the task.

What does ‘UnicodeDecodeError’ or ‘UnicodeEncodeError’ error mean? See the Unicode HOWTO.

Performance My program is too slow. How do I speed it up? That’s a tough one, in general. First, here are a list of things to remember before diving further:

Performance characteristics vary across Python implementations. This FAQ focuses on CPython.

Behaviour can vary across operating systems, especially when talking about I/O or multi-threading.

You should always find the hot spots in your program before attempting to optimize any code (see the profile module).

Writing benchmark scripts will allow you to iterate quickly when searching for improvements (see the timeit module).

It is highly recommended to have good code coverage (through unit testing or any other technique) before potentially introducing regressions hidden in sophisticated optimizations.

That being said, there are many tricks to speed up Python code. Here are some general principles which go a long way towards reaching acceptable performance levels:

Making your algorithms faster (or changing to faster ones) can yield much larger benefits than trying to sprinkle micro-optimization tricks all over your code.

Use the right data structures. Study documentation for the Built-in Types and the collections module.

When the standard library provides a primitive for doing something, it is likely (although not guaranteed) to be faster than any alternative you may come up with. This is doubly true for primitives written in C, such as builtins and some extension types. For example, be sure to use either the list.sort() built-in method or the related sorted() function to do sorting (and see the Sorting HOW TO for examples of moderately advanced usage).

Abstractions tend to create indirections and force the interpreter to work more. If the levels of indirection outweigh the amount of useful work done, your program will be slower. You should avoid excessive abstraction, especially under the form of tiny functions or methods (which are also often detrimental to readability).

If you have reached the limit of what pure Python can allow, there are tools to take you further away. For example, Cython can compile a slightly modified version of Python code into a C extension, and can be used on many different platforms. Cython can take advantage of compilation (and optional type annotations) to make your code significantly faster than when interpreted. If you are confident in your C programming skills, you can also write a C extension module yourself.

See also The wiki page devoted to performance tips. What is the most efficient way to concatenate many strings together? str and bytes objects are immutable, therefore concatenating many strings together is inefficient as each concatenation creates a new object. In the general case, the total runtime cost is quadratic in the total string length.

To accumulate many str objects, the recommended idiom is to place them into a list and call str.join() at the end:

chunks = [] for s in my_strings: chunks.append(s) result = ''.join(chunks) (another reasonably efficient idiom is to use io.StringIO)

To accumulate many bytes objects, the recommended idiom is to extend a bytearray object using in-place concatenation (the += operator):

result = bytearray() for b in my_bytes_objects: result += b Sequences (Tuples/Lists) How do I convert between tuples and lists? The type constructor tuple(seq) converts any sequence (actually, any iterable) into a tuple with the same items in the same order.

For example, tuple([1, 2, 3]) yields (1, 2, 3) and tuple('abc') yields ('a', 'b', 'c'). If the argument is a tuple, it does not make a copy but returns the same object, so it is cheap to call tuple() when you aren’t sure that an object is already a tuple.

The type constructor list(seq) converts any sequence or iterable into a list with the same items in the same order. For example, list((1, 2, 3)) yields [1, 2, 3] and list('abc') yields ['a', 'b', 'c']. If the argument is a list, it makes a copy just like seq[:] would.

What’s a negative index? Python sequences are indexed with positive numbers and negative numbers. For positive numbers 0 is the first index 1 is the second index and so forth. For negative indices -1 is the last index and -2 is the penultimate (next to last) index and so forth. Think of seq[-n] as the same as seq[len(seq)-n].

Using negative indices can be very convenient. For example S[:-1] is all of the string except for its last character, which is useful for removing the trailing newline from a string.

How do I iterate over a sequence in reverse order? Use the reversed() built-in function:

for x in reversed(sequence): ... # do something with x ... This won’t touch your original sequence, but build a new copy with reversed order to iterate over.

How do you remove duplicates from a list? See the Python Cookbook for a long discussion of many ways to do this:

https://code.activestate.com/recipes/52560/

If you don’t mind reordering the list, sort it and then scan from the end of the list, deleting duplicates as you go:

if mylist: mylist.sort() last = mylist[-1] for i in range(len(mylist)-2, -1, -1): if last == mylist[i]: del mylist[i] else: last = mylist[i] If all elements of the list may be used as set keys (i.e. they are all hashable) this is often faster

mylist = list(set(mylist)) This converts the list into a set, thereby removing duplicates, and then back into a list.

How do you remove multiple items from a list As with removing duplicates, explicitly iterating in reverse with a delete condition is one possibility. However, it is easier and faster to use slice replacement with an implicit or explicit forward iteration. Here are three variations.:

mylist[:] = filter(keep_function, mylist) mylist[:] = (x for x in mylist if keep_condition) mylist[:] = [x for x in mylist if keep_condition] The list comprehension may be fastest.

How do you make an array in Python? Use a list:

["this", 1, "is", "an", "array"] Lists are equivalent to C or Pascal arrays in their time complexity; the primary difference is that a Python list can contain objects of many different types.

The array module also provides methods for creating arrays of fixed types with compact representations, but they are slower to index than lists. Also note that the Numeric extensions and others define array-like structures with various characteristics as well.

To get Lisp-style linked lists, you can emulate cons cells using tuples:

lisp_list = ("like", ("this", ("example", None) ) ) If mutability is desired, you could use lists instead of tuples. Here the analogue of lisp car is lisp_list[0] and the analogue of cdr is lisp_list[1]. Only do this if you’re sure you really need to, because it’s usually a lot slower than using Python lists.

How do I create a multidimensional list? You probably tried to make a multidimensional array like this:

A = [[None] * 2] * 3 This looks correct if you print it:

A [[None, None], [None, None], [None, None]] But when you assign a value, it shows up in multiple places:

A[0][0] = 5 A [[5, None], [5, None], [5, None]] The reason is that replicating a list with * doesn’t create copies, it only creates references to the existing objects. The *3 creates a list containing 3 references to the same list of length two. Changes to one row will show in all rows, which is almost certainly not what you want.

The suggested approach is to create a list of the desired length first and then fill in each element with a newly created list:

A = [None] * 3 for i in range(3): A[i] = [None] * 2 This generates a list containing 3 different lists of length two. You can also use a list comprehension:

w, h = 2, 3 A = [[None] * w for i in range(h)] Or, you can use an extension that provides a matrix datatype; NumPy is the best known.

How do I apply a method to a sequence of objects? Use a list comprehension:

result = [obj.method() for obj in mylist] Why does a_tuple[i] += [‘item’] raise an exception when the addition works? This is because of a combination of the fact that augmented assignment operators are assignment operators, and the difference between mutable and immutable objects in Python.

This discussion applies in general when augmented assignment operators are applied to elements of a tuple that point to mutable objects, but we’ll use a list and += as our exemplar.

If you wrote:

a_tuple = (1, 2) a_tuple[0] += 1 Traceback (most recent call last): ... TypeError: 'tuple' object does not support item assignment The reason for the exception should be immediately clear: 1 is added to the object a_tuple[0] points to (1), producing the result object, 2, but when we attempt to assign the result of the computation, 2, to element 0 of the tuple, we get an error because we can’t change what an element of a tuple points to.

Under the covers, what this augmented assignment statement is doing is approximately this:

result = a_tuple[0] + 1 a_tuple[0] = result Traceback (most recent call last): ... TypeError: 'tuple' object does not support item assignment It is the assignment part of the operation that produces the error, since a tuple is immutable.

When you write something like:

a_tuple = (['foo'], 'bar') a_tuple[0] += ['item'] Traceback (most recent call last): ... TypeError: 'tuple' object does not support item assignment The exception is a bit more surprising, and even more surprising is the fact that even though there was an error, the append worked:

a_tuple[0] ['foo', 'item'] To see why this happens, you need to know that (a) if an object implements an iadd magic method, it gets called when the += augmented assignment is executed, and its return value is what gets used in the assignment statement; and (b) for lists, iadd is equivalent to calling extend on the list and returning the list. That’s why we say that for lists, += is a “shorthand” for list.extend:

a_list = [] a_list += [1] a_list [1] This is equivalent to:

result = a_list.iadd([1]) a_list = result The object pointed to by a_list has been mutated, and the pointer to the mutated object is assigned back to a_list. The end result of the assignment is a no-op, since it is a pointer to the same object that a_list was previously pointing to, but the assignment still happens.

Thus, in our tuple example what is happening is equivalent to:

result = a_tuple[0].iadd(['item']) a_tuple[0] = result Traceback (most recent call last): ... TypeError: 'tuple' object does not support item assignment The iadd succeeds, and thus the list is extended, but even though result points to the same object that a_tuple[0] already points to, that final assignment still results in an error, because tuples are immutable.

I want to do a complicated sort: can you do a Schwartzian Transform in Python? The technique, attributed to Randal Schwartz of the Perl community, sorts the elements of a list by a metric which maps each element to its “sort value”. In Python, use the key argument for the list.sort() method:

Isorted = L[:] Isorted.sort(key=lambda s: int(s[10:15])) How can I sort one list by values from another list? Merge them into an iterator of tuples, sort the resulting list, and then pick out the element you want.

list1 = ["what", "I'm", "sorting", "by"] list2 = ["something", "else", "to", "sort"] pairs = zip(list1, list2) pairs = sorted(pairs) pairs [("I'm", 'else'), ('by', 'sort'), ('sorting', 'to'), ('what', 'something')] result = [x[1] for x in pairs] result ['else', 'sort', 'to', 'something'] Objects What is a class? A class is the particular object type created by executing a class statement. Class objects are used as templates to create instance objects, which embody both the data (attributes) and code (methods) specific to a datatype.

A class can be based on one or more other classes, called its base class(es). It then inherits the attributes and methods of its base classes. This allows an object model to be successively refined by inheritance. You might have a generic Mailbox class that provides basic accessor methods for a mailbox, and subclasses such as MboxMailbox, MaildirMailbox, OutlookMailbox that handle various specific mailbox formats.

What is a method? A method is a function on some object x that you normally call as x.name(arguments...). Methods are defined as functions inside the class definition:

class C: def meth(self, arg): return arg * 2 + self.attribute What is self? Self is merely a conventional name for the first argument of a method. A method defined as meth(self, a, b, c) should be called as x.meth(a, b, c) for some instance x of the class in which the definition occurs; the called method will think it is called as meth(x, a, b, c).

See also Why must ‘self’ be used explicitly in method definitions and calls?.

How do I check if an object is an instance of a given class or of a subclass of it? Use the built-in function isinstance(obj, cls). You can check if an object is an instance of any of a number of classes by providing a tuple instead of a single class, e.g. isinstance(obj, (class1, class2, ...)), and can also check whether an object is one of Python’s built-in types, e.g. isinstance(obj, str) or isinstance(obj, (int, float, complex)).

Note that isinstance() also checks for virtual inheritance from an abstract base class. So, the test will return True for a registered class even if hasn’t directly or indirectly inherited from it. To test for “true inheritance”, scan the MRO of the class:

from collections.abc import Mapping

class P: pass

class C(P): pass

Mapping.register(P)

c = C() isinstance(c, C) # direct True isinstance(c, P) # indirect True isinstance(c, Mapping) # virtual True

Actual inheritance chain type(c).mro (<class 'C'>, <class 'P'>, <class 'object'>)

Test for "true inheritance" Mapping in type(c).mro False Note that most programs do not use isinstance() on user-defined classes very often. If you are developing the classes yourself, a more proper object-oriented style is to define methods on the classes that encapsulate a particular behaviour, instead of checking the object’s class and doing a different thing based on what class it is. For example, if you have a function that does something:

def search(obj): if isinstance(obj, Mailbox): ... # code to search a mailbox elif isinstance(obj, Document): ... # code to search a document elif ... A better approach is to define a search() method on all the classes and just call it:

class Mailbox: def search(self): ... # code to search a mailbox

class Document: def search(self): ... # code to search a document

obj.search() What is delegation? Delegation is an object oriented technique (also called a design pattern). Let’s say you have an object x and want to change the behaviour of just one of its methods. You can create a new class that provides a new implementation of the method you’re interested in changing and delegates all other methods to the corresponding method of x.

Python programmers can easily implement delegation. For example, the following class implements a class that behaves like a file but converts all written data to uppercase:

class UpperOut:

def init(self, outfile): self._outfile = outfile

def write(self, s): self._outfile.write(s.upper())

def getattr(self, name): return getattr(self._outfile, name) Here the UpperOut class redefines the write() method to convert the argument string to uppercase before calling the underlying self._outfile.write() method. All other methods are delegated to the underlying self._outfile object. The delegation is accomplished via the getattr method; consult the language reference for more information about controlling attribute access.

Note that for more general cases delegation can get trickier. When attributes must be set as well as retrieved, the class must define a setattr() method too, and it must do so carefully. The basic implementation of setattr() is roughly equivalent to the following:

class X: ... def setattr(self, name, value): self.dict[name] = value ... Most setattr() implementations must modify self.dict to store local state for self without causing an infinite recursion.

How do I call a method defined in a base class from a derived class that overrides it? Use the built-in super() function:

class Derived(Base): def meth(self): super(Derived, self).meth() For version prior to 3.0, you may be using classic classes: For a class definition such as class Derived(Base): ... you can call method meth() defined in Base (or one of Base’s base classes) as Base.meth(self, arguments...). Here, Base.meth is an unbound method, so you need to provide the self argument.

How can I organize my code to make it easier to change the base class? You could assign the base class to an alias and derive from the alias. Then all you have to change is the value assigned to the alias. Incidentally, this trick is also handy if you want to decide dynamically (e.g. depending on availability of resources) which base class to use. Example:

class Base: ...

BaseAlias = Base

class Derived(BaseAlias): ... How do I create static class data and static class methods? Both static data and static methods (in the sense of C++ or Java) are supported in Python.

For static data, simply define a class attribute. To assign a new value to the attribute, you have to explicitly use the class name in the assignment:

class C: count = 0 # number of times C.init called

def init(self): C.count = C.count + 1

def getcount(self): return C.count # or return self.count c.count also refers to C.count for any c such that isinstance(c, C) holds, unless overridden by c itself or by some class on the base-class search path from c.class back to C.

Caution: within a method of C, an assignment like self.count = 42 creates a new and unrelated instance named “count” in self’s own dict. Rebinding of a class-static data name must always specify the class whether inside a method or not:

C.count = 314 Static methods are possible:

class C: @staticmethod def static(arg1, arg2, arg3): # No 'self' parameter! ... However, a far more straightforward way to get the effect of a static method is via a simple module-level function:

def getcount(): return C.count If your code is structured so as to define one class (or tightly related class hierarchy) per module, this supplies the desired encapsulation.

How can I overload constructors (or methods) in Python? This answer actually applies to all methods, but the question usually comes up first in the context of constructors.

In C++ you’d write

class C { C() { cout << "No arguments\n"; } C(int i) { cout << "Argument is " << i << "\n"; } } In Python you have to write a single constructor that catches all cases using default arguments. For example:

class C: def init(self, i=None): if i is None: print("No arguments") else: print("Argument is", i) This is not entirely equivalent, but close enough in practice.

You could also try a variable-length argument list, e.g.

def init(self, *args): ... The same approach works for all method definitions.

I try to use __spam and I get an error about _SomeClassName__spam. Variable names with double leading underscores are “mangled” to provide a simple but effective way to define class private variables. Any identifier of the form __spam (at least two leading underscores, at most one trailing underscore) is textually replaced with _classname__spam, where classname is the current class name with any leading underscores stripped.

This doesn’t guarantee privacy: an outside user can still deliberately access the “_classname__spam” attribute, and private values are visible in the object’s dict. Many Python programmers never bother to use private variable names at all.

My class defines del but it is not called when I delete the object. There are several possible reasons for this.

The del statement does not necessarily call del() – it simply decrements the object’s reference count, and if this reaches zero del() is called.

If your data structures contain circular links (e.g. a tree where each child has a parent reference and each parent has a list of children) the reference counts will never go back to zero. Once in a while Python runs an algorithm to detect such cycles, but the garbage collector might run some time after the last reference to your data structure vanishes, so your del() method may be called at an inconvenient and random time. This is inconvenient if you’re trying to reproduce a problem. Worse, the order in which object’s del() methods are executed is arbitrary. You can run gc.collect() to force a collection, but there are pathological cases where objects will never be collected.

Despite the cycle collector, it’s still a good idea to define an explicit close() method on objects to be called whenever you’re done with them. The close() method can then remove attributes that refer to subobjects. Don’t call del() directly – del() should call close() and close() should make sure that it can be called more than once for the same object.

Another way to avoid cyclical references is to use the weakref module, which allows you to point to objects without incrementing their reference count. Tree data structures, for instance, should use weak references for their parent and sibling references (if they need them!).

Finally, if your del() method raises an exception, a warning message is printed to sys.stderr.

How do I get a list of all instances of a given class? Python does not keep track of all instances of a class (or of a built-in type). You can program the class’s constructor to keep track of all instances by keeping a list of weak references to each instance.

Why does the result of id() appear to be not unique? The id() builtin returns an integer that is guaranteed to be unique during the lifetime of the object. Since in CPython, this is the object’s memory address, it happens frequently that after an object is deleted from memory, the next freshly created object is allocated at the same position in memory. This is illustrated by this example:

id(1000) 13901272 id(2000) 13901272 The two ids belong to different integer objects that are created before, and deleted immediately after execution of the id() call. To be sure that objects whose id you want to examine are still alive, create another reference to the object:

a = 1000; b = 2000 id(a) 13901272 id(b) 13891296 When can I rely on identity tests with the is operator? The is operator tests for object identity. The test a is b is equivalent to id(a) == id(b).

The most important property of an identity test is that an object is always identical to itself, a is a always returns True. Identity tests are usually faster than equality tests. And unlike equality tests, identity tests are guaranteed to return a boolean True or False.

However, identity tests can only be substituted for equality tests when object identity is assured. Generally, there are three circumstances where identity is guaranteed:

Assignments create new names but do not change object identity. After the assignment new = old, it is guaranteed that new is old.

Putting an object in a container that stores object references does not change object identity. After the list assignment s[0] = x, it is guaranteed that s[0] is x.

If an object is a singleton, it means that only one instance of that object can exist. After the assignments a = None and b = None, it is guaranteed that a is b because None is a singleton.

In most other circumstances, identity tests are inadvisable and equality tests are preferred. In particular, identity tests should not be used to check constants such as int and str which aren’t guaranteed to be singletons:

a = 1000 b = 500 c = b + 500 a is c False

a = 'Python' b = 'Py' c = b + 'thon' a is c False Likewise, new instances of mutable containers are never identical:

a = [] b = [] a is b False In the standard library code, you will see several common patterns for correctly using identity tests:

As recommended by PEP 8, an identity test is the preferred way to check for None. This reads like plain English in code and avoids confusion with other objects that may have boolean values that evaluate to false.

Detecting optional arguments can be tricky when None is a valid input value. In those situations, you can create an singleton sentinel object guaranteed to be distinct from other objects. For example, here is how to implement a method that behaves like dict.pop():

_sentinel = object()

def pop(self, key, default=_sentinel): if key in self: value = self[key] del self[key] return value if default is _sentinel: raise KeyError(key) return default 3) Container implementations sometimes need to augment equality tests with identity tests. This prevents the code from being confused by objects such as float('NaN') that are not equal to themselves.

For example, here is the implementation of collections.abc.Sequence.contains():

def contains(self, value): for v in self: if v is value or v == value: return True return False Modules How do I create a .pyc file? When a module is imported for the first time (or when the source file has changed since the current compiled file was created) a .pyc file containing the compiled code should be created in a pycache subdirectory of the directory containing the .py file. The .pyc file will have a filename that starts with the same name as the .py file, and ends with .pyc, with a middle component that depends on the particular python binary that created it. (See PEP 3147 for details.)

One reason that a .pyc file may not be created is a permissions problem with the directory containing the source file, meaning that the pycache subdirectory cannot be created. This can happen, for example, if you develop as one user but run as another, such as if you are testing with a web server.

Unless the PYTHONDONTWRITEBYTECODE environment variable is set, creation of a .pyc file is automatic if you’re importing a module and Python has the ability (permissions, free space, etc…) to create a pycache subdirectory and write the compiled module to that subdirectory.

Running Python on a top level script is not considered an import and no .pyc will be created. For example, if you have a top-level module foo.py that imports another module xyz.py, when you run foo (by typing python foo.py as a shell command), a .pyc will be created for xyz because xyz is imported, but no .pyc file will be created for foo since foo.py isn’t being imported.

If you need to create a .pyc file for foo – that is, to create a .pyc file for a module that is not imported – you can, using the py_compile and compileall modules.

The py_compile module can manually compile any module. One way is to use the compile() function in that module interactively:

import py_compile py_compile.compile('foo.py') This will write the .pyc to a pycache subdirectory in the same location as foo.py (or you can override that with the optional parameter cfile).

You can also automatically compile all files in a directory or directories using the compileall module. You can do it from the shell prompt by running compileall.py and providing the path of a directory containing Python files to compile:

python -m compileall . How do I find the current module name? A module can find out its own module name by looking at the predefined global variable name. If this has the value 'main', the program is running as a script. Many modules that are usually used by importing them also provide a command-line interface or a self-test, and only execute this code after checking name:

def main(): print('Running test...') ...

if name == 'main': main() How can I have modules that mutually import each other? Suppose you have the following modules:

foo.py:

from bar import bar_var foo_var = 1 bar.py:

from foo import foo_var bar_var = 2 The problem is that the interpreter will perform the following steps:

main imports foo

Empty globals for foo are created

foo is compiled and starts executing

foo imports bar

Empty globals for bar are created

bar is compiled and starts executing

bar imports foo (which is a no-op since there already is a module named foo)

bar.foo_var = foo.foo_var

The last step fails, because Python isn’t done with interpreting foo yet and the global symbol dictionary for foo is still empty.

The same thing happens when you use import foo, and then try to access foo.foo_var in global code.

There are (at least) three possible workarounds for this problem.

Guido van Rossum recommends avoiding all uses of from import ..., and placing all code inside functions. Initializations of global variables and class variables should use constants or built-in functions only. This means everything from an imported module is referenced as ..

Jim Roskind suggests performing steps in the following order in each module:

exports (globals, functions, and classes that don’t need imported base classes)

import statements

active code (including globals that are initialized from imported values).

van Rossum doesn’t like this approach much because the imports appear in a strange place, but it does work.

Matthias Urlichs recommends restructuring your code so that the recursive import is not necessary in the first place.

These solutions are not mutually exclusive.

import(‘x.y.z’) returns <module ‘x’>; how do I get z? Consider using the convenience function import_module() from importlib instead:

z = importlib.import_module('x.y.z') When I edit an imported module and reimport it, the changes don’t show up. Why does this happen? For reasons of efficiency as well as consistency, Python only reads the module file on the first time a module is imported. If it didn’t, in a program consisting of many modules where each one imports the same basic module, the basic module would be parsed and re-parsed many times. To force re-reading of a changed module, do this:

import importlib import modname importlib.reload(modname) Warning: this technique is not 100% fool-proof. In particular, modules containing statements like

from modname import some_objects will continue to work with the old version of the imported objects. If the module contains class definitions, existing class instances will not be updated to use the new class definition. This can result in the following paradoxical behaviour:

import importlib import cls c = cls.C() # Create an instance of C importlib.reload(cls) <module 'cls' from 'cls.py'> isinstance(c, cls.C) # isinstance is false?!? False The nature of the problem is made clear if you print out the “identity” of the class objects:

hex(id(c.class)) '0x7352a0' hex(id(cls.C)) '0x4198d0' Table of Contents Programming FAQ General Questions Core Language Numbers and strings Performance Sequences (Tuples/Lists) Objects Modules Previous topic General Python FAQ

Next topic Design and History FAQ

This Page Report a Bug Show Source This question already has answers here: Is there a way to put comments in multiline code? (2 answers) Closed 3 years ago. I am trying to write some Python example code with a line commented out:

user_by_email = session.query(User) .filter(Address.email=='one') #.options(joinedload(User.addresses)) .first() I also tried:

user_by_email = session.query(User) .filter(Address.email=='one')\

.options(joinedload(User.addresses))
.first() But I get IndentationError: unexpected indent. If I remove the commented out line, the code works. I am decently sure that I use only spaces (Notepad++ screenshot):

enter image description here def unique(s): """Return a list of the elements in s, but without duplicates.

For example, unique([1,2,3,1,2,3]) is some permutation of [1,2,3], unique("abcabc") some permutation of ["a", "b", "c"], and unique(([1, 2], [2, 3], [1, 2])) some permutation of [[2, 3], [1, 2]].

For best speed, all sequence elements should be hashable. Then unique() will usually work in linear time.

If not possible, the sequence elements should enjoy a total ordering, and if list(s).sort() doesn't raise TypeError it's assumed that they do enjoy a total ordering. Then unique() will usually work in O(N*log2(N)) time.

If that's not possible either, the sequence elements must support equality-testing. Then unique() will usually work in quadratic time. """

n = len(s) if n == 0: return []

Try using a dict first, as that's the fastest and will usually
work. If it doesn't work, it will usually fail quickly, so it
usually doesn't cost much to try it. It requires that all the
sequence elements be hashable, and support equality comparison.
u = {} try: for x in s: u[x] = 1 except TypeError: del u # move on to the next method else: return u.keys()

We can't hash all the elements. Second fastest is to sort,
which brings the equal elements together; then duplicates are
easy to weed out in a single pass.
NOTE: Python's list.sort() was designed to be efficient in the
presence of many duplicate elements. This isn't true of all
sort functions in all languages or libraries, so this approach
is more effective in Python than it may be elsewhere.
try: t = list(s) t.sort() except TypeError: del t # move on to the next method else: assert n > 0 last = t[0] lasti = i = 1 while i < n: if t[i] != last: t[lasti] = last = t[i] lasti += 1 i += 1 return t[:lasti]

Brute force is all that's left.
u = [] for x in s: if x not in u: u.append(x) return u ] for x in s: if x not in u: u.append( x) return u
/bin/bash

if [ "$(uname)" == 'Darwin' ]; then
  OS='Mac'
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  OS='Linux'
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

case $(basename $0) in
  atom-beta)
    CHANNEL=beta
    ;;
  atom-nightly)
    CHANNEL=nightly
    ;;
  atom-dev)
    CHANNEL=dev
    ;;
  *)
    CHANNEL=stable
    ;;
esac

# Only set the ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT env var if it hasn't been set.
if [ -z "$ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT" ]
then
  export ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT=true
fi

ATOM_ADD=false
ATOM_NEW_WINDOW=false
EXIT_CODE_OVERRIDE=

while getopts ":anwtfvh-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        add)
          ATOM_ADD=true
          ;;
        new-window)
          ATOM_NEW_WINDOW=true
          ;;
        wait)
          WAIT=1
          ;;
        help|version)
          REDIRECT_STDERR=1
          EXPECT_OUTPUT=1
          ;;
        foreground|benchmark|benchmark-test|test)
          EXPECT_OUTPUT=1
          ;;
        enable-electron-logging)
          export ELECTRON_ENABLE_LOGGING=1
          ;;
      esac
      ;;
    a)
      ATOM_ADD=true
      ;;
    n)
      ATOM_NEW_WINDOW=true
      ;;
    w)
      WAIT=1
      ;;
    h|v)
      REDIRECT_STDERR=1
      EXPECT_OUTPUT=1
      ;;
    f|t)
      EXPECT_OUTPUT=1
      ;;
  esac
done

if [ "${ATOM_ADD}" = "true" ] && [ "${ATOM_NEW_WINDOW}" = "true" ]; then
  EXPECT_OUTPUT=1
  EXIT_CODE_OVERRIDE=1
fi

if [ $REDIRECT_STDERR ]; then
  exec 2> /dev/null
fi

ATOM_HOME="${ATOM_HOME:-$HOME/.atom}"
mkdir -p "$ATOM_HOME"

if [ $OS == 'Mac' ]; then
  if [ -L "$0" ]; then
    SCRIPT="$(readlink "$0")"
  else
    SCRIPT="$0"
  fi
  ATOM_APP="$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT")")")")"
  if [ "$ATOM_APP" == . ]; then
    unset ATOM_APP
  else
    ATOM_PATH="$(dirname "$ATOM_APP")"
    ATOM_APP_NAME="$(basename "$ATOM_APP")"
  fi

  if [ ! -z "${ATOM_APP_NAME}" ]; then
    # If ATOM_APP_NAME is known, use it as the executable name
    ATOM_EXECUTABLE_NAME="${ATOM_APP_NAME%.*}"
  else
    # Else choose it from the inferred channel name
    if [ "$CHANNEL" == 'beta' ]; then
      ATOM_EXECUTABLE_NAME="Atom Beta"
    elif [ "$CHANNEL" == 'nightly' ]; then
      ATOM_EXECUTABLE_NAME="Atom Nightly"
    elif [ "$CHANNEL" == 'dev' ]; then
      ATOM_EXECUTABLE_NAME="Atom Dev"
    else
      ATOM_EXECUTABLE_NAME="Atom"
    fi
  fi

  if [ -z "${ATOM_PATH}" ]; then
    # If ATOM_PATH isn't set, check /Applications and then ~/Applications for Atom.app
    if [ -x "/Applications/$ATOM_APP_NAME" ]; then
      ATOM_PATH="/Applications"
    elif [ -x "$HOME/Applications/$ATOM_APP_NAME" ]; then
      ATOM_PATH="$HOME/Applications"
    else
      # We haven't found an Atom.app, use spotlight to search for Atom
      ATOM_PATH="$(mdfind "kMDItemCFBundleIdentifier == 'com.github.atom'" | grep -v ShipIt | head -1 | xargs -0 dirname)"

      # Exit if Atom can't be found
      if [ ! -x "$ATOM_PATH/$ATOM_APP_NAME" ]; then
        echo "Cannot locate ${ATOM_APP_NAME}, it is usually located in /Applications. Set the ATOM_PATH environment variable to the directory containing ${ATOM_APP_NAME}."
        exit 1
      fi
    fi
  fi

  if [ $EXPECT_OUTPUT ]; then
    "$ATOM_PATH/$ATOM_APP_NAME/Contents/MacOS/$ATOM_EXECUTABLE_NAME" --executed-from="$(pwd)" --pid=$$ "$@"
    ATOM_EXIT=$?
    if [ ${ATOM_EXIT} -eq 0 ] && [ -n "${EXIT_CODE_OVERRIDE}" ]; then
      exit "${EXIT_CODE_OVERRIDE}"
    else
      exit ${ATOM_EXIT}
    fi
  else
    open -a "$ATOM_PATH/$ATOM_APP_NAME" -n --args --executed-from="$(pwd)" --pid=$$ --path-environment="$PATH" "$@"
  fi
elif [ $OS == 'Linux' ]; then
  SCRIPT=$(readlink -f "$0")
  USR_DIRECTORY=$(readlink -f $(dirname $SCRIPT)/..)

  case $CHANNEL in
    beta)
      ATOM_PATH="$USR_DIRECTORY/share/atom-beta/atom"
      ;;
    nightly)
      ATOM_PATH="$USR_DIRECTORY/share/atom-nightly/atom"
      ;;
    dev)
      ATOM_PATH="$USR_DIRECTORY/share/atom-dev/atom"
      ;;
    *)
      ATOM_PATH="$USR_DIRECTORY/share/atom/atom"
      ;;
  esac

  : ${TMPDIR:=/tmp}

  [ -x "$ATOM_PATH" ] || ATOM_PATH="$TMPDIR/atom-build/Atom/atom"

  if [ $EXPECT_OUTPUT ]; then
    "$ATOM_PATH" --executed-from="$(pwd)" --pid=$$ "$@"
    ATOM_EXIT=$?
    if [ ${ATOM_EXIT} -eq 0 ] && [ -n "${EXIT_CODE_OVERRIDE}" ]; then
      exit "${EXIT_CODE_OVERRIDE}"
    else
      exit ${ATOM_EXIT}
    fi
  else
    (
    nohup "$ATOM_PATH" --executed-from="$(pwd)" --pid=$$ "$@" > "$ATOM_HOME/nohup.out" 2>&1
    if [ $? -ne 0 ]; then
      cat "$ATOM_HOME/nohup.out"
      exit $?
    fi
    ) &
  fi
fi

# Exits this process when Atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# If the wait flag is set, don't exit this process until Atom kills it.
if [ $WAIT ]; then
  WAIT_FIFO="$ATOM_HOME/.wait_fifo"

  if [ ! -p "$WAIT_FIFO" ]; then
    rm -f "$WAIT_FIFO"
    mkfifo "$WAIT_FIFO"
  fi

  # Block endlessly by reading from a named pipe.
  exec 2>/dev/null
  read < "$WAIT_FIFO"

  # If the read completes for some reason, fall back to sleeping in a loop.
  while true; do
    sleep 1
  done
fi
