#lang pollen/mode racket/base
#|
We can write a pollen.rkt file in any #lang. `#lang racket` is more convenient because it loads more
libraries by default. For the same reason, `#lang racket/base` — with a minimal set of libraries — is
slightly faster to load. The difference here is probably negligible.

In general, the more virtuous habit is `#lang racket/base`.

`pollen/mode` is a metalanguage that adds support for Pollen-mode commands in a source file.
So instead of `#lang racket/base` we write `#lang pollen/mode racket/base`. `pollen/mode` is optional.

BTW this file is heavily commented so it can serve as a Pollen learning tool. Rather than just read
along, you are encouraged to run this project with the project server active, and make changes to this
file and see how they affect the output.

We could avoid the next line if we were using `#lang racket`, because these libraries would already
be available.
|#
(require
  (for-syntax racket/base racket/syntax) ; enables macros
  racket/list
  racket/format
  racket/string
  racket/function
  racket/contract
  racket/system
  txexpr
  pollen/decode
  pollen/tag
  hyphenate
  sugar/list
  sugar/coerce
  sugar/file
  sugar/debug
  "pricing-table.rkt")


#|
Everything provided from a pollen.rkt will be automatically available to Pollen source files in the
same directory or subdirectories (unless superseded by another pollen.rkt, as in the "fonts" subdir)

Note that `all-defined-out` would only export the definitions that are created in this file. To make
imported definitions available too, we need to re-export them with `all-from-out`.
|#
(provide (all-defined-out) (all-from-out "pricing-table.rkt"))


#|
The 'config' submodule has special status: It can be used to alter project settings. Here, we'll use
it to omit all "woff" files from the published project.
See docs for `pollen/world` and `world:unpublished-path?`.
|#
(module config racket/base
  (provide (all-defined-out)) ;; <- don't forget this line in your config submodule!
  (define (unpublished-path? p)
    (regexp-match "woff" (path->string p))))


#|
Pollen recognizes the environment variable POLLEN, which can take any value.
For instance, instead of starting the project server with

    raco pollen start

You could do

    POLLEN=SOME-STRING raco pollen start

And "SOME-STRING" would be loaded into the POLLEN environment variable.

We can retrieve this value with `(getenv "POLLEN")`. It can be used to create branching behavior.
Here, we'll create a `dev-mode?` test and use it later to change the behavior of certain functions.
|#
(define (dev-mode?)
  (equal? (getenv "POLLEN") "DEV"))


#|
Definitions in a pollen.rkt can be functions or values.
Here are a couple values.
|# 
(define content-rule-color "#444") ; for CSS classes
(define buy-url "http://typo.la/oc") ; link to buy the Typography for Lawyers paperback


#|

TAG FUNCTIONS

|#

#|
`link`: make a hyperlink

In Pollen notation, we'll invoke the tag function like so:

  ◊link[url]{text of link}
  ◊link[url #:class "name"]{text of link}

This will become, in Racket notation:

  (link url "text of link")
  (link url #:class "name" "text of link")

The definition of the tag function will follow this syntax.

Learning to see the duality of Pollen & Racket notation is a necessary part of the learning curve.
Pollen notation is optimized for embedding commands in text.
Racket notation is optimized for writing code.

The relationship between the two, however, is dependable and consistent.

By contrast, most "template languages" either make you use syntax that's different from the
underlying language, or restrict you to a subset of commands.

Whereas any Racket command can be expressed in Pollen notation. So having two equivalent notation
systems ultimately lets you do more, not less.

|#

#|
The definition of `link` follows the arguments above.
`url` is a mandatory argument.
`class` is a keyword argument (= must be introduced with #:class) and also optional (if it's not
provided, it will default to #f).
`xs` is a rest argument, as in "put the rest of the arguments here." Most definitions of tag functions
should end with a rest argument. Why? Because in Pollen notation, the `{text ...}`
in `◊func[arg]{text ...}` can return any number of arguments. Maybe one (e.g., if `text` is a word)
or maybe more (e.g, if `text ...` is a multiline block).

If you DON'T use a rest argument, and pass multiple text arguments to your tag function, you will get
an error (namely an "arity error", which means the function got more arguments than it expected).

The result of our tag function will be a tagged X-expression that looks like this:

  '(a ((href "url")) "text to link")
  '(a ((href "url")(class "name")) "text to link")

X-expressions and tagged X-expressions are introduced in the Pollen docs.
|#

(define (link url #:class [class-name #f] . text-args)
  (define no-text-arguments? (empty? text-args))
  (if no-text-arguments?
      (let ([text-to-link url])
        ;; if we don't have any text to link, use `url` as the link text too.
        (link #:class class-name url text-to-link))
      ;; otherwise, create the basic tagged X-expression,
      ;; and then add the `url` and (maybe) `class` attributes.
      ;; `let*` is the idiomatic Racket way to mutate a variable.
      ;; (Spoiler alert: you're not really mutating, you're creating copies.)
      ;; You could also use `set!` — not wrong, but not idiomatic.
      (let*
          ;; A tagged X-expression is just a list of stuff,
          ;; so you can make one with any of Racket's list-making functions.
          ;; Here, we're using `make-txexpr` for maximum clarity:
          ;; it takes a tag name, list of attributes, and list of elements.
          ;; We could also use
          ;; 1) quasiquote: `(a ,null ,@xs) or `(a ,@xs)
          ;; 2) list*: (list* 'a null xs) or (list* 'a xs)
          ;; 3) append: (append (list 'a) null xs)
          ;; The point is not to baffle you, but rather show that there's no special magic to
          ;; a tagged X-expression, and no special need to use `make-txexpr` at all times.
          ;; The major advantage of `make-txexpr` is that it will raise an error
          ;; if your arguments are invalid types for a tagged X-expression.
          ;; Generic functions like `list` and `append` will not.
          ([link-tx (make-txexpr 'a null text-args)]
           
           ;; `attr-set` is from the `txexpr` module. It updates an attribute value
           ;; and returns an updated X-expression.
           [link-tx (attr-set link-tx 'href url)]
           [link-tx (if class-name
                        (attr-set link-tx 'class class-name)
                        link-tx)])
        link-tx)))

#|
UNIT TESTS

Testing, as always, is optional, but strongly recommended. Unit tests are little one-line tests that
prove your function does what it says. As you refactor and reorganize your code, your unit tests will
let you know if you broke anything.

You can make unit tests with the `rackunit` library. Though you can put your unit tests in a separate
source file, I generally prefer to put them close to the function that they're testing. (For details
on the testing functions used below, see the docs for `rackunit`)

The ideal way to do this is with a `test` submodule. The code in a `test` submodule will only be used
a) when you run the file in DrRacket or
b) when `raco test` runs the file.
Otherwise, it is ignored.

We'll use the `module+` syntax for this. As the name suggests, `module+` creates a submodule that
incorporates everything else already in the source file. Moreover, all of our `module+ test` blocks
will be combined into a single submodule.
|#

(module+ test
  (require rackunit) ;; always include this at the start of the test submodule
  
  ;; we use `check-txexprs-equal?` rather than `check-equal?` because it's a little more lenient:
  ;; it allows the attributes of two txexprs to be in a different order,
  ;; yet still be considered equal (because ordering of attributes is not semantically significant).
  (check-txexprs-equal? (link "http://foo.com" "link text")
                        '(a ((href "http://foo.com")) "link text"))
  ;; The last test was fine, but it can be even better if we use a Pollen-mode command on the left.
  ;; That way, we can directly compare the command as it appears in Pollen input
  ;; with how it appears in the output.
  (check-txexprs-equal? ◊link["http://foo.com"]{link text}
                        '(a ((href "http://foo.com")) "link text"))
  
  ;; It's wise to test as many valid input situations as you can.
  (check-txexprs-equal? ◊link["http://foo.com" #:class 'main]{link text}
                        '(a ((href "http://foo.com")(class "main")) "link text"))
  (check-txexprs-equal? ◊link["http://foo.com"]
                        '(a ((href "http://foo.com")) "http://foo.com"))
  
  ;; Strictly speaking, you could also write the last Pollen command like so:
  (check-txexprs-equal? ◊link{http://foo.com} '(a ((href "http://foo.com")) "http://foo.com"))
  
  ;; That's not wrong. But in the interests of code readability,
  ;; I like to reserve the curly brackets in a Pollen command
  ;; for material that I expect to see displayed in the output
  ;; (e.g., textual and other content),
  ;; and use the square brackets for the other arguments.
  
  ;; You can also check that errors arise when they should.
  ;; Note that when testing for exceptions, you need to wrap your test expression in a function
  ;; (so that its evaluation can be delayed, otherwise you'd get the error immediately.)
  ;; The `(λ _ expression)` notation is a simple way.
  ;; (The `_` is the idiomatic way to notate something that will be ignored, in this case arguments.)
  (check-exn exn:fail? (λ _ ◊link[])) ; no arguments
  (check-exn exn:fail? (λ _ ◊link[#:invalid-keyword 42])) ; invalid keyword argument
  (check-exn exn:fail? (λ _ ◊link[#f]))) ; invalid argument

;; For the sake of brevity, I'm going to write just one test for the remaining functions.
;; But you're encouraged to add more tests (or break the existing ones and see what happens).



#|
The next three tag functions are just convenience variations of `link`.
But they involve some crafty (and necessary) uses of `apply`.
|#

#|
`buy-book-link`: makes a link with a particular URL.

Notice that we have to use `apply` to correctly pass our `text-args` rest argument to `link`.
Why? Because `link` expects its text arguments to look like this:

  (link url text-arg-1 text-arg-2 ...)

Not like this:

  (link url (list text-arg-1 text-arg-2 ...))

But that's what will happen if we just do `(link text-args)`, and `link` will complain. (Try it!)

The role of `apply` is to take a list of arguments and append them to the end of the function call, so

  (apply link url (list text-arg-1 text-arg-2 ...))

Is equivalent to:

  (link url text-arg-1 text-arg-2 ...)

|#

(define (buy-book-link . text-args)
  (apply link buy-url text-args))

(module+ test
  ;; notice that we use `buy-url` in our test result.
  ;; That way, if we change the value of `buy-url`, the test won't break.
  (check-txexprs-equal? ◊buy-book-link{link text} `(a ((href ,buy-url)) "link text")))

#|
`buylink`: creates a link styled with the "buylink" class.
`home-link`: creates a link styled with the "home-link" class.

The difference here is that we're not providing a specific URL. Rather, we want to pass through
whatever URL we get from the Pollen source. So we add a `url` argument.
|#
(define (buylink url . text-args)
  (apply link url #:class "buylink" text-args))

(module+ test
  (check-txexprs-equal? ◊buylink["http://foo.com"]{link text}
                        '(a ((href "http://foo.com")(class "buylink")) "link text")))


(define (home-link url . text-args)
  (apply link url #:class "home-link" text-args))

(module+ test
  (check-txexprs-equal? ◊home-link["http://foo.com"]{link text}
                        '(a ((href "http://foo.com")(class "home-link")) "link text")))

#|
BTW we could also be let the rest argument capture the URL,
and just pass everything through with `apply`, which will work the same way:

  (define (buylink . url-and-text-args)
    (apply link #:class "buylink" url-and-text-args))

The other definition is more readable and explicit, however.
|#


#|
`image`: make an img tag

We proceed as we did with `link`. But in this case, we don't need a rest argument
because this tag function doesn't accept text arguments.

"Right, but shouldn't you use a rest argument just in case?" It depends on how you like errors
to be handled. You could capture the text arguments with a rest argument and then just silently
dispose of them. But this might be mysterious to the person editing the Pollen source (whether you
or someone else). "Where did my text go?"

Whereas if we omit the rest argument, and try to pass text arguments anyhow, `image` will immediately
raise an error, letting us know that we're misusing it.
|#
(define (image src #:width [width "100%"] #:border [border? #t])
  (let* ([img-tag '(img)]
         [img-tag (attr-set img-tag 'style (format "width: ~a" width))]
         [img-tag (attr-set img-tag 'src (build-path "images" src))]
         [img-tag (if border?
                      (attr-set img-tag 'class "bordered")
                      img-tag)])
    img-tag))


(module+ test
  (check-txexprs-equal? ◊image["pic.gif"]
                        '(img ((style "width: 100%") (class "bordered")(src "images/pic.gif"))))
  (check-txexprs-equal? ◊image[#:border #f "pic.gif"]
                        '(img ((style "width: 100%")(src "images/pic.gif"))))
  (check-txexprs-equal? ◊image[#:width "50%" "pic.gif"]
                        '(img ((style "width: 50%")(class "bordered")(src "images/pic.gif")))))


#|

`div-scale`: wrap tag in a 'div' with a scaling factor

  ◊div-scale[.75]{text here ...}

|#
(define (div-scale factor . text-args)
  ; use `format` on factor because it might be either a string or a number
  (define base (make-txexpr 'div null text-args))
  (attr-set base 'style (format "width: ~a" factor))) 

(module+ test
  (check-txexprs-equal? ◊div-scale[.5]{Hello} '(div ((style "width: 0.5")) "Hello")))


#|

`font-scale`: wrap tag in a 'span' with a relative font-scaling factor

  ◊font-scale[.75]{text here ...}

|#
(define (font-scale ratio . text-args)
  (define base (make-txexpr 'span null text-args))
  (attr-set base 'style (format "font-size: ~aem" ratio)))

(module+ test
  (check-txexprs-equal? ◊font-scale[.75]{Hello}
                        '(span ((style "font-size: 0.75em")) "Hello")))


#|

`home-image`: make an image with class "home-image"

  ◊home-image[image-path]

|#
(define (home-image image-path)
  (attr-set (image image-path) 'class "home-image"))

(module+ test
  (check-txexprs-equal? ◊home-image["pic.gif"]
                        '(img ((style "width: 100%") (class "home-image") (src "images/pic.gif")))))


#|

`home-overlay`: create nested divs where the text sits atop a background image.

  ◊home-overlay[image-name]{text}

This is an example of how fiddly HTML chores can be encapsulated / hidden inside a tag function.
This makes your source files tidier.
It also makes it possible to change the fiddly HTML markup from one central location.
|#
(define (home-overlay img-path . text-args)
  `(div ((class "home-overlay")(style ,(format "background-image: url('~a')" img-path)))
        (div ((class "home-overlay-inner")) ,@text-args)))

(module+ test
  (check-txexprs-equal? ◊home-overlay["pic.gif"]{Hello}
                        '(div ((class "home-overlay") (style "background-image: url('pic.gif')"))
                              (div ((class "home-overlay-inner")) "Hello"))))


#|

`glyph`: create a span with the class "glyph".

  ◊glyph{text}

Here, I'll use `make-default-tag-function`, which is an easy way to make a simple tag function.
Any keywords passed in will be propagated to every use of the tag function.
|#
(define glyph (make-default-tag-function 'span #:class "glyph"))

(module+ test
  (check-txexprs-equal? ◊glyph{X}
                        '(span ((class "glyph")) "X"))
  (check-txexprs-equal? ◊glyph[#:id "top"]{X}
                        '(span ((class "glyph")(id "top")) "X")))


#|

`image-wrapped`: like `image` but with some extra attributes

  ◊image-wrapped[img-path]

|#
(define (image-wrapped img-path)
  (attr-set* (image img-path) 'class "icon" 'style "width: 120px;" 'align "left"))

(module+ test
  (check-txexprs-equal? ◊image-wrapped{my-path}
                        '(img ((class "icon")
                               (style "width: 120px;")
                               (align "left")
                               (src "images/my-path")))))

#|

`detect-list-items`: helper function for other tag functions that make HTML lists.

The idea is to automatically convert a sequence of three (or more) linebreaks
into a new list item (i.e., <li> tag).

Why three? Because later on, we'll make one linebreak = new line and two linebreaks = new paragraph.

This function will be used within a `decode` function (more on that below)
in a position where it will be passed a list of X-expresssion elements,
and needs to return a list of X-expression elements.

The idiomatic Racket way to enforce requirements on input & output values is with a function contract.
For simplicity, I'm not using them here.
|#
(define (detect-list-items elems)
  
  ;; We need to do some defensive preprocessing here.
  ;; Our list of elements could contain sequences like "\n" "\n" "\n"
  ;; that should mean the same thing as "\n\n\n".
  ;; So we combine adjacent newlines with `merge-newlines`.
  (define elems-merged (merge-newlines elems))
  
  ;; Then, a list item break is denoted by any element that matches three or more newlines.
  (define (list-item-break? elem)
    (define list-item-separator-pattern (regexp "\n\n\n+"))
    
    ;; Python people will object to the `(string? elem)` test below
    ;; as a missed chance for "duck typing".
    ;; You can do duck typing in Racket (see `with-handlers`) but it's not idiomatic.
    ;; IMO this is wise. Duck typing is an anti-pattern: it substitutes an explicit, readable test
    ;; for an implicit test ("I know if such-and-such isn't true, then a certain error will arise."
    (and (string? elem) (regexp-match list-item-separator-pattern elem)))
  
  ;; `filter-split` will divide a list into sublists based on a certain test.
  ;; the result will be a list of lists, each representing the contents of an 'li tag.
  (define list-of-li-elems (filter-split elems-merged list-item-break?))
  
  ;; We convert any paragraphs that are inside the list items.
  (define list-of-li-paragraphs (map (λ(li) (detect-paragraphs li #:force? #t)) list-of-li-elems))
  
  ;; Finally we wrap each of these lists of paragraphs in an 'li tag.
  (define li-tag (make-default-tag-function 'li))
  (map (λ(lip) (apply li-tag lip)) list-of-li-paragraphs))

(module+ test
  (check-equal? (detect-list-items '("foo" "\n" "bar")) ; linebreak, not list item break
                '((li (p "foo" (br) "bar"))))
  (check-equal? (detect-list-items '("foo" "\n" "\n" "bar")) ; paragraph break, not list item break
                '((li (p "foo") (p "bar"))))
  (check-equal? (detect-list-items '("foo" "\n" "\n" "\n" "bar")) ; list item break
                '((li (p "foo")) (li (p "bar"))))
  (check-equal? (detect-list-items '("foo" "\n\n\n" "bar")) ; list item break, concatenated
                '((li (p "foo")) (li (p "bar"))))
  (check-equal? (detect-list-items '("foo" "\n" "\n" "\n\n\n" "bar")) ; list item break
                '((li (p "foo")) (li (p "bar")))))


#|
`make-list-function`: helper function that makes other tag functions that make lists.

  (make-list-function 'list-tag-name)
  (make-list-function 'list-tag-name '((attr-key "attr-value") ...))

In Racket you will often see functions that make other functions.
This is a good way to avoid making a bunch of functions that have small variations.

One way to write this function is like so:

(define (listifier . args)
  (list* tag attrs (detect-list-items args)))
listifier

That is, explicitly define a new function called `listifier` and then return that function.
That's the best way to do it in many programming languages.

In Racket, it's not wrong, but you should feel comfortable
with the idea that any function can be equivalently expressed in lambda notation,
which is the more Rackety idiom.

The code below has the same meaning, but without having to `define` an intermediate variable.
|#
(define (make-list-function tag [attrs empty])
  (λ args (list* tag attrs (detect-list-items args))))


#|
Now we can define `bullet-list` and `numbered-list` using our helper function.
|#

(define bullet-list (make-list-function 'ul))
(define numbered-list (make-list-function 'ol))

(module+ test
  (check-txexprs-equal? (bullet-list "foo") '(ul (li (p "foo"))))
  (check-txexprs-equal? (numbered-list "foo") '(ol (li (p "foo")))))


#|
`btw`: make the "By the Way" list at the bottom of many pages,
e.g. http://typographyforlawyers.com/what-is-typography.html

  ◊btw{text ...}

Another example of using a tag function to handle fiddly HTML markup.
The `btw` tag expands to an HTML list, which we will then crack open and add a headline div.
|#
(define (btw . text-args)
  (define btw-tag-function (make-list-function 'ul '((class "btw"))))
  ;; Why is `apply` needed here? See the explanation for `buy-book-link` above.
  (define btw-list (apply btw-tag-function text-args))
  (list* (get-tag btw-list)
         (get-attrs btw-list)
         '(div ((id "btw-title")) "by the way")
         (get-elements btw-list)))

(module+ test
  (check-txexprs-equal? (btw "foo" "\n" "\n" "\n" "bar")
                        '(ul ((class "btw"))
                             (div ((id "btw-title")) "by the way")
                             (li (p "foo"))
                             (li (p "bar")))))

#|
`xref`: create a styled cross-reference link, with optional destination argument.

  ◊xref{target}
  ◊xref["url"]{target}

For this tag function, we will assume that target is a single text argument,
because that's how it will be used.
But to be safe, we'll raise an arity error if we get too many arguments.
|#
(define xref
  ;; What makes this function a little tricky is that the url argument is optional,
  ;; but if it appears, it appears first.
  ;; This is a good job for `case-lambda`, which lets you define separate branches for your function
  ;; depending on the total number of arguments provided.
  (case-lambda
    
    ;; one argument: must be a target. Note the Rackety recursive technique here:
    ;; we'll create a second argument and then call `xref` again.
    [(target) (xref (target->url target) target)]

    ;; two arguments: must be a url followed by a target.
    [(url target) (apply attr-set* (link url target) 'class "xref" no-hyphens-attr)]

    ;; more than two arguments: raise an arity error.
    [more-than-two-args (apply raise-arity-error 'xref (list 1 2) more-than-two-args)]))


(module+ test
  (check-txexprs-equal? (xref "target")
                        '(a ((class "xref") (href "target.html") (hyphens "none")) "target"))
  (check-txexprs-equal? (xref "url" "target")
                        '(a ((class "xref") (href "url") (hyphens "none")) "target"))
  (check-exn exn:fail:contract:arity? (λ _ (xref "url" "target" "spurious-third-argument"))))
  
                        

(define (target->url target)
  (define nonbreaking-space (~a #\u00A0))
  (let* ([xn target]
         [xn (string-trim xn "?")]
         [xn (string-downcase xn)]
         [xn (regexp-replace* #rx"é" xn "e")]
         [xn (if (regexp-match #rx"^foreword" xn) "foreword" xn)]
         [xn (if (regexp-match #rx"^table of contents" xn) "toc" xn)]
         [xn (string-replace xn nonbreaking-space "-")]
         [xn (string-replace xn " " "-")])
    (format "~a.html" xn)))

(define (xref-font font-name)
  (xref (format "fontrec/~a" (target->url font-name)) font-name))



(define-syntax-rule (define-heading name tag)
  (define (name #:class [class-string ""] . xs)
    `(,tag ((class ,(string-trim (format "~a ~a" 'name class-string))) ,no-hyphens-attr) ,@xs)))

(define-heading topic 'h3)
(define-heading subhead 'h3)
(define-heading font-headline 'h3)
(define-heading section 'h2)
(define-heading chapter 'h1)

(define title-key 'title)

(define-syntax (define-thing-from-metas stx)
  (syntax-case stx ()
    [(_ thing)
     (with-syntax ([thing-from-metas (format-id stx "~a-from-metas" #'thing)])
       #'(define (thing-from-metas metas)
           (thing (hash-ref metas title-key))))]))

(define-thing-from-metas topic)
(define-thing-from-metas section)
(define-thing-from-metas chapter)

(define (hanging-topic topic-xexpr . xs)
  `(div ((class "hanging-topic") ,no-hyphens-attr) ,topic-xexpr (p (,no-hyphens-attr) ,@xs)))

(define omission (make-default-tag-function 'div #:class "omission"))

(define no-hyphens-attr '(hyphens "none"))

(define (hyphenate-block block-tx)
  ;; attach hyphenate as a block processor rather than string processor
  ;; so that attrs can be inspected for "no-hyphens" flag.
  (define (no-hyphens? tx)
    (or (member (get-tag tx) '(th h1 h2 h3 h4 style script))
        (member no-hyphens-attr (get-attrs tx))))
  (hyphenate block-tx
             #:min-left-length 3
             #:min-right-length 3
             #:omit-txexpr no-hyphens?))

(define (hangable-quotes str)
  (define strs (regexp-match* #px"\\s?[“‘]" str #:gap-select? #t))
  (if (= (length strs) 1) ; no submatches
      (car strs)
      (cons 'quo (append-map (λ(str)
                               (let ([strlen (string-length str)])
                                 (if (> strlen 0)
                                     (case (substring str (sub1 strlen) strlen)
                                       [("‘") (list '(squo-push) `(squo-pull ,str))]
                                       [("“") (list '(dquo-push) `(dquo-pull ,str))]
                                       [else (list str)])
                                     (list str)))) strs))))


(define (fix-em-dashes str)
  ;; remove word spaces around em dashes where necessary.
  ;; replace with thin spaces.
  ;; \u00A0 = nbsp, \u2009 = thinsp (neither included in \s) 
  
  (let* ([str (regexp-replace* #px"(?<=\\w)[\u00A0\u2009\\s]—" str "—")]
         [str (regexp-replace* #px"—[\u00A0\u2009\\s](?=\\w)" str "—")])
    str))

(define (root . xs)
  ;; process paragraphs first so that they're treated as block-txexprs in next phase.
  (define elements-with-paragraphs (decode-elements xs #:txexpr-elements-proc detect-paragraphs)) 
  `(div ((id "doc")) ,@(decode-elements elements-with-paragraphs
                                        #:block-txexpr-proc hyphenate-block
                                        ;; `hangable-quotes` doesn't return a string, so do it last
                                        #:string-proc (compose1 hangable-quotes
                                                                fix-em-dashes
                                                                smart-quotes)
                                        #:exclude-tags '(style script))))


(define (gap [size 1.5])
  `(div ((style ,(format "height: ~arem" size)))))

(define (center . xs)
  `(div ((style "text-align:center")) ,@xs))
(define (map-tag tag-name elems)
  (map (curry list tag-name) elems))

(define (map-splicing-tag tag-name elems)
  (map (curry cons tag-name) elems))

(define (tabulate celled-rows)
  (define header-row (car celled-rows))
  (define other-rows (cdr celled-rows))
  `(table ,@(map-splicing-tag 'tr
                              (cons
                               (map-tag 'th header-row)
                               (for/list ([celled-row (in-list other-rows)])
                                         (map-tag 'td celled-row))))))

(define (quick-table . xs)
  (define rows (filter-not whitespace? xs))
  (define celled-rows
    (for/list ([row (in-list rows)])
              (map (λ(cell) (string-trim cell)) (string-split row "|"))))
  (tabulate celled-rows))

(define (indented #:hyphenate [hyphenate #t]  . xs)
  `(p ((class "indented"),@(if (not hyphenate) (list no-hyphens-attr) null)) ,@xs))

(define caption-runin (make-default-tag-function 'span #:class "caption-runin"))

(define caption (make-default-tag-function 'span #:class "caption"))

(define (captioned name . xs)
  `(table ((class "captioned indented"))
          (tr (td ((style "text-align:left")) ,@xs) (td  ,(caption name)))))


(define mono (make-default-tag-function 'span #:class "mono"))



(define/contract (pdf-thumbnail-link pdf-pathstring)
  (path-string? . -> . any/c)
  (define img-extension "gif")
  (define img-pathstring (->string (add-ext (remove-ext pdf-pathstring) img-extension)))
  (define sips-command
    (format "sips -Z 2000 -s format ~a --out '~a' '~a' > /dev/null"
            img-extension img-pathstring pdf-pathstring))
  (let ([result (system sips-command)])
    (if result
        (link pdf-pathstring `(img ((src ,img-pathstring))))
        (error 'pdf-thumbnail-link "sips failed"))))

(define (pdf-thumbnail-link-from-metas metas)
  (define-values (dir fn _) (split-path (add-ext (remove-ext* (hash-ref metas 'here-path)) "pdf")))
  (pdf-thumbnail-link (->string fn)))

(define (before-and-after-pdfs base-name)
  `(div 
    (div ((class "pdf-thumbnail"))
         "before" (br)
         ,(pdf-thumbnail-link (format "pdf/sample-doc-~a-before.pdf" base-name)))
    (div ((class "pdf-thumbnail"))
         "after" (br)
         ,(pdf-thumbnail-link (format "pdf/sample-doc-~a-after.pdf" base-name)))))

(define (alternate-after-pdf base-name)
  `(div ((class "pdf-thumbnail"))
        "after (alternate)" (br)
        ,(pdf-thumbnail-link (format "pdf/sample-doc-~a-after-alternate.pdf" base-name))))

(define (random-select . xs)
  (list-ref xs (random (length xs))))

(define font-details (make-default-tag-function 'div #:class "font-details"))

(define mb-font-specimen
  (make-default-tag-function 'div #:class "mb-font-specimen" #:contenteditable "true"))

(define (margin-note . xs)
  `(div ((class "margin-note") ,no-hyphens-attr) ,@xs))

(define os (make-default-tag-function 'span #:class "os"))


(define (capitalize-first-letter str)
  (regexp-replace #rx"^." str string-upcase))