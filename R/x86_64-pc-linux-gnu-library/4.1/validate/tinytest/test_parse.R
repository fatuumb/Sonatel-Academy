

## file paths are interpreted correctly ----
  expect_true(validate:::is_full_path("C:/hello"))
  expect_true(validate:::is_full_path("//server/hello"))
  expect_true(validate:::is_full_path("~/hello"))
  expect_true(validate:::is_full_path("http://hello"))
  expect_false(validate:::is_full_path("./hello"))
  expect_false(validate:::is_full_path("reldir/hello"))
  # windoze flavor
  expect_true(validate:::is_full_path("C:\\hello"))
  expect_true(validate:::is_full_path("\\\\server\\hello"))
  expect_true(validate:::is_full_path("~\\hello"))
  expect_false(validate:::is_full_path("reldir\\hello"))

# TODO: add file parsing tests
#setwd("pkg/tests/testthat/")
## Parsing freeform ----
  expect_equal( length( validator(.file="yamltests/freeform.yaml") ) , 2)
  expect_equal( length( indicator(.file="yamltests/indicator.yaml") ) , 2)
  expect_equal( length( indicator(.file="yamltests/indicator2.yaml") ) , 2)

## Parsing yrf format ----
  now <- Sys.time()
  v <- validator(.file="yamltests/yamlrules.yaml")
  expect_equal(length(v),2)
  expect_equal(names(v),c("sumrule","conditional"))
  expect_equivalent(origin(v),c("yamltests/yamlrules.yaml","yamltests/yamlrules.yaml"))
  expect_equivalent(label(v),c("sum of x and y","if x positive then y also"))
  expect_equivalent(description(v),c("a looong description here","a looong description here\n"))
  expect_true(all(created(v)-now < 10))
  expect_warning(validator(.file="yamltests/invalid.yaml"))
  out <- capture.output(expect_warning(validator(.file="yamltests/invalidR.yaml")))
  expect_true(any(nchar(out)>0))

## Duplicate names ----
  v <- validator(.file="yamltests/duplicate_name.yaml") 
  nms <- names(v)
  expect_equal(nms, unique(nms))

## Parsing options ----
  v <- validator(.file="yamltests/yamloptions.yaml") 
  expect_equal(voptions(v,"raise"),"all")
  expect_equal(length(v),1)

##Parsing metadata ----
  v <- validator(.file="yamltests/yaml_with_meta.yaml")
  expect_equal(meta(v)$foo,c("1",NA))
  expect_equal(meta(v)$bar,c(NA,"2"))

## Parsing included files ----
  v <- validator(.file="yamltests/top.yaml")
  expect_equal(length(v),6)
  expect_equivalent(origin(v)
    , c(  "yamltests/child1.yaml"
        , "yamltests/child1.yaml"
        , "yamltests/child3.yaml"
        , "yamltests/child2.yaml"
        , "yamltests/child2.yaml"
        , "yamltests/top.yaml")
    , info = "file inclusion order"
    )

## validation from data.frames ----
  
  d <- data.frame(
  rule = c("x>0", "a + b == c")
    , name = c("foo", "bar")
    , description = c("hello world","Ola, mundo")
    , stringsAsFactors=FALSE
  )
  expect_equal(length(validator(.data=d)),2)
  expect_equal(length( validator(.data=d[-3]) ),2)
  expect_error(validator(.data=d[-1]))
  d$rule[2] <- "a+b"
  expect_warning(validator(.data=d))
  



# 
##  var_from_call ----
  
  # regular case, concering two variables
  expect_equal(
    validate:::var_from_call(expression(x > y)[[1]])
    , c("x","y")
  )
  
  
  # case of no variables at all
  expect_equal(
    validate:::var_from_call(expression(1 > 0)[[1]])
    , NULL
  )

## validating_call ----
  expect_true(validate:::validating_call(expression(x > y)[[1]]))
  expect_true(validate:::validating_call(expression(x >= y)[[1]]))
  expect_true(validate:::validating_call(expression(x == y)[[1]]))
  expect_true(validate:::validating_call(expression(x != y)[[1]]))
  expect_true(validate:::validating_call(expression(x <= y)[[1]]))
  expect_true(validate:::validating_call(expression(x < y)[[1]]))
  expect_true(validate:::validating_call(expression(identical(x,y))[[1]]))

  expect_true(validate:::validating_call(expression(!(x > y))[[1]]))
  expect_true(validate:::validating_call(expression(all(x > y))[[1]]))
  expect_true(validate:::validating_call(expression(any(x > y))[[1]]))
  expect_true(validate:::validating_call(expression(grepl('hello',x))[[1]]))

  # Removed test (2020-09-08): can be done with "hihi" %in% names(.)
#  expect_true(validate:::validating_call(expression(exists("hihi")==TRUE)[[1]]))

  expect_true(validate:::validating_call(expression(if(x == 1) y == 1)[[1]]))
  expect_true(validate:::validating_call(expression(xor(x == 1, y == 1))[[1]]))
  expect_false(validate:::validating_call(expression(x)[[1]]))
  

## vectorizing if-statmentes ----

  a <- validate:::vectorize( expression( if (P) Q )[[1]]  )
  b <- expression(!(P) |(Q))[[1]]
  expect_identical(a,b)

  a <- validate:::vectorize( expression( (if (P) Q) )[[1]]  )
  b <- expression( (!(P)|(Q)) )[[1]]  
  expect_identical(a,b)

  a <- validate:::vectorize( expression( (if (P) Q) | Z   )[[1]]  )
  b <- expression((!(P)|(Q)) | Z)[[1]]
  expect_identical(a,b)

  a <- expression(sapply(x,function(y) 2*y))[[1]]
  b <- a
  expect_identical(validate:::vectorize(a),b)

  a <- validate:::vectorize( expression( (if (P) Q) | (if(A) B)   )[[1]]  )
  b <- expression((!(P)|(Q))|(!(A)|(B)))[[1]]
  expect_identical(a,b)

  # nested if's. For some reasons, identical gives FALSE
  a <- validate:::vectorize(expression( if (P) Q | if(A) B )[[1]])
  b <- expression( !(P) | (Q | (!(A) | (B))) )[[1]]
  expect_true(a == b)
  
  e <- expression( if (P) Q else R)[[1]]
  a <- validate:::vectorize(e)
  b <- expression(
    (!(P)|(Q)) & ((P)|(R))
  )[[1]]
  expect_identical(a,b)


## translation of rules to data.frame ----
  v <- validator(x > y, 2*y-1==z)
  expect_equal(nrow(as.data.frame(v)),2)
  i <- indicator(mean(x), sd(y))
  expect_equal(nrow(as.data.frame(i)),2)


## replacing %in% operator ----
  e <- expression( x %in% y)[[1]]
  expect_identical(validate:::replace_in(e)
    , expression(x %vin% y)[[1]])
  
  e <- expression( x %in% y | x %in% z)[[1]]
  expect_identical(validate:::replace_in(e)
    , expression(x %vin% y | x %vin% z)[[1]])
  

## negating numerical expressions
e  <- expression(x >  1, x >=1, x <  1, x <=1, x == 1, x != 1, !(x == 1))
ne <- expression(x <= 1, x < 1, x >= 1, x > 1, x != 1, x == 1, (x == 1))
expect_identical( as.expression(lapply(e, validate:::negate))
                , ne
                )

## injecting eps
e <- quote(x >= 1)
expect_identical( validate:::replace_lin(e, dat=data.frame(x=1), eps_ineq = 0.1)
                , quote(x - 1 >= -0.1)
                )

e <- quote(!x>0)
expect_identical( validate:::replace_lin(e, dat=data.frame(x=1), eps_ineq = 0.1)
                , quote(x <= 0
                )
)

e <- quote(!(x>0))
expect_identical( validate:::replace_lin(e, dat=data.frame(x=1), eps_ineq = 0.1)
                  , quote(x <= 0
                  )
)


e <- quote(if (x > 1) y == 1 else z > 1)
expect_identical( validate:::replace_lin(e, dat=data.frame(x=1, y=1,z=1),eps_ineq = 0.1, eps_eq = 0.2)
                , quote(if (x > 1) abs(y - 1) <= 0.2 else z > 1)
)

e <- quote(if (x > 1) y == 1 else z > 1)
e <- validate:::replace_if(e)
e <- validate:::replace_lin(e, dat=data.frame(x=1,y=1,z=1))
expect_identical( e 
                , quote(  (x <= 1  | (abs(y - 1) <= 0.1)) 
                       & ((x >  1) | (z > 1))
                       )
                )

e <- quote(a == b)
e <- validate:::replace_lin(e, dat=data.frame(a = 1, b=2))
expect_identical( e, quote(abs(a - b) <= 0.1))

e <- quote(a == b)
e <- validate:::replace_lin(e, dat=data.frame(a = "A", b="B"))
expect_identical( e, quote(a == b))

                  