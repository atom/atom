p(String *Class)
class String
class Class
end
end
#def String(x) x.to_s end #it's already built-in. duh!
def String.*(right) [self,right] end
def String.<<(right) [self,:<<,right] end
def String./(right) [self,:/,right] end
def String.[](right) [self,:[],right] end
p(String::Class)
p(String:: Class)
p(String ::Class)
p(String :: Class)
p(String<<Class)
p(String<< Class)
p(String <<Class) 
sgsdfgf
Class
p(String << Class)
p(String/Class)
p(String/ Class)
p(String /Class/) 
p(String / Class) #borken
p(String[Class])
p(String[ Class])
p(String [Class]) 
p(String [ Class]) 
p(String*Class)
p(String* Class)
p(String *Class) 
p(String * Class)
class <<String
undef :*,<<,/,[]
end



p(false::to_s)
p(false ::to_s)
p(false:: to_s)
p(false :: to_s)

class C2
class <<self
  def self.p8; p 8 end
  alias p? p
  alias P? p
  alias [] p
  alias <=> p
end

q=9
Q=99

p:p8
false ? p: p8
p :p8
false ? p : p8

false ? q:p8
false ? q: p8
false ? q :p8
false ? q : p8

#false ? Q:p8  #gives ruby indigestion
false ? Q: p8
#false ? Q :p8  #gives ruby indigestion
false ? Q : p8

p?:p8
false ? p?: p8
p? :p8
false ? p? : p8

P?:p8
false ? P?: p8
P? :p8
false ? P? : p8

self.[]:p8
false ? self.[]: p8
self.[] :p8
false ? self.[] : p8

self.<=>:p8
false ? self.<=>: p8
self.<=> :p8
false ? self.<=> : p8

self <=>:p8
#false ? self <=>: p8  #gives ruby indigestion
self <=> :p8
#false ? self <=> : p8  #gives ruby indigestion
end

p <<stuff+'foobar'.tr('j-l','d-f')
"more stuff"
12345678
the quick brown fox jumped over the lazy dog
stuff


p <<p
sdfsfdf^^^^@@@
p
mix=nil
p / 5/mix

module M33
  p="var:"
  Q="func:"
  def Q.method_missing(name,*args)
    self+name.to_s+(args.join' ')
  end
  def p.method_missing(name,*args)
    self+name.to_s+(args.join' ')
  end
  def self.p(*a); super; Q end
  @a=1
  $a=2
  
  p(p~6)
  p(p ~6)
  p(p~ 6)
  p(p ~ 6)
  p(p*11)
  p(p *11)
  p(p* 11)
  p(p * 11)
  p(p&proc{})
  p(p &proc{})
  p(p& proc{})
  p(p & proc{})
  p(p !1)
#  p(p ?1) #compile error, when p is var
  p(p ! 1)
  p(p ? 1 : 6)
  p(p@a)
  p(p @a)
#  p(p@ a)  #wont
#  p(p @ a) #work 
  p(p#a
)
  p(p #a
)
  p(p# a
)
  p(p # a
)
  p(p$a)
  p(p $a)
#  p(p$ a)  #wont
#  p(p $ a) #work
  p(p%Q{:foo})
  p(p %Q{:foo})
  p(p% Q{:foo})
  p(p % Q{:foo})
  p(p^6)
  p(p ^6)
  p(p^ 6)
  p(p ^ 6)
  p(p&7)
  p(p &proc{7})
  p(p& 7)
  p(p & 7)
  p(p(2))
  p(p (2))
  p(p( 2))
  p(p ( 2))
  p(p(p))
  p(p())
  p(p (p))
  p(p ())
  p(p ( p))
  p(p ( ))
  p(p( p))
  p(p( ))
  p(p)
  p((p))
  p(p )
  p((p ))
  p((p p))
  p((p p,p))
  p((p p))
  p((p p,p))
  p(p-0)
  p(p -0)
  p(p- 0)
  p(p - 0)
  p(p+9)
  p(p +9)
  p(p+ 9)
  p(p + 9)
  p(p[1])
  p(p [1])
  p(p[ 1])
  p(p [ 1])
  p(p{1})
  p(p {1})
  p(p{ 1})
  p(p { 1})
  p(p/1)
  p(p /22)
  p(p/ 1)
  p(p / 22)
  p(p._)
  p(p ._)
  p(p. _)
  p(p . _)
  p(false ? p:f)
  p(false ? p :f)
  p(false ? p: f)
  p(false ? p : f)
  p((p;1))
  p((p ;1))
  p((p; 1))
  p((p ; 1))
  p(p<1)
  p(p <1)
  p(p< 1)
  p(p < 1)
  p(p<<1)
  p(p <<1)
  p(p<< 1)
  p(p << 1)
  p(p'j')
  p(p 'j')
  p(p' j')
  p(p ' j')
  p(p"k")
  p(p "k")
  p(p" k")
  p(p " k")
  p(p|4)
  p(p |4)
  p(p| 4)
  p(p | 4)
  p(p>2)
  p(p >2)
  p(p> 2)
  p(p > 2)
  
end

module M34
  p(p~6)
  p(p ~6)
  p(p~ 6)
  p(p ~ 6)
  p(p*[1])
  p(p *[1])
  p(p* [1])
  p(p * [1])
  p(p&proc{})
  p(p &proc{})
  p(p& proc{})
  p(p & proc{})
  p(p !1)
  p(p ?1)
  p(p ! 1)
  p(p ? 1 : 6)
  p(p@a)
  p(p @a)
#  p(p@ a)  #wont
#  p(p @ a) #work 

  p(p#a
)
  p(p #a
)
  p(p# a
)
  p(p # a
)
  p(p$a)
  p(p $a)
#  p(p$ a)  #wont
#  p(p $ a) #work
  p(p%Q{:foo})
  p(p %Q{:foo})
  p(p% Q{:foo})
  p(p % Q{:foo})
  p(p^6)
  p(p ^6)
  p(p^ 6)
  p(p ^ 6)
  p(p&7)
  p(p &proc{7})
  p(p& 7)
  p(p & 7)
  p(p(2))
  p(p (2))
  p(p( 2))
  p(p ( 2))
  p(p(p))
  p(p())
  p(p (p))
  p(p ())
  p(p ( p))
  p(p ( ))
  p(p( p))
  p(p( ))
  p(p)
  p((p))
  p(p )
  p((p ))
  p((p p))
  p((p p,p))
  p((p p))
  p((p p,p))
  p(p-0)
  p(p -1)
  p(p- 0)
  p(p - 0)
  p(p+9)
  p(p +9)
  p(p+ 9)
  p(p + 9)
  p(p[1])
  p(p [1])
  p(p[ 1])
  p(p [ 1])
  p(p{1})
  p(p {1})
  p(p{ 1})
  p(p { 1})
  p(p/1)
  p(p /22/)
  p(p/ 1)
  p(p / 22)
  p(p._)
  p(p ._)
  p(p. _)
  p(p . _)
  p(p:f)
  p(p :f)
  p(false ? p: f)
  p(false ? p : f)
  p((p;1))
  p((p ;1))
  p((p; 1))
  p((p ; 1))
  p(p<1)
  p(p <1)
  p(p< 1)
  p(p < 1)
  p(p<<1)
  p(p <<1)
foobar
1
  p(p<< 1)
  p(p << 1)
  p(p'j')
  p(p 'j')
  p(p' j')
  p(p ' j')
  p(p"k")
  p(p "k")
  p(p" k")
  p(p " k")
  p(p|4)
  p(p |4)
  p(p| 4)
  p(p | 4)
  p(p>2)
  p(p >2)
  p(p> 2)
  p(p > 2)
  
end


def bob(x) x end
def bill(x) x end
p(bob %(22))
for bob in [100] do p(bob %(22)) end
p(bob %(22))
def %(n) to_s+"%#{n}" end
p(bill %(22))
begin sdjkfsjkdfsd; rescue Object => bill; p(bill %(22)) end
p(bill %(22))
undef %

class Object

public :`
def `(s)
  print "bq: #{s}\n"
end
end

69.`('what a world')

79::`('what a word')

p :`

p{}
p {}
a=5
p p +5
p a +5

def nil.+(x) ~x end
def nil.[](*x) [x] end
p( p + 5 )
p( p +5 )
p( p+5 )
p( p[] )
p( p [] )
p( p [ ] )
class NilClass; undef +,[] end

class Foou
 public
 def [] x=-100,&y; p x; 100 end
end
a0=8
p Foou.new.[]!false  #value
p Foou.new.[] !false #value
p Foou.new.[]~9      #value
p Foou.new.[] ~9     #value
p Foou.new.[]-9      #op
p Foou.new.[]+9      #op
p Foou.new.[] -9     #value
p Foou.new.[] +9     #value
p Foou.new.[]<<9     #op
p Foou.new.[] <<9    #value
foobar
9
p Foou.new.[]%9      #op
p Foou.new.[]/9      #op
p Foou.new.[] %(9)   #value
p Foou.new.[] /9/    #value
p Foou.new.[]$9      #value
p Foou.new.[]a0      #value
p Foou.new.[] $9     #value
p Foou.new.[] a0     #value
p Foou.new.[]{9}     #lambda (op)
p Foou.new.[] {9}    #lambda (op)

if p then p end

p({:foo=>:bar})   #why does this work? i'd think that ':foo=' would be 1 token
p   EMPTY = 0
p   BLACK = 1
p   WHITE = - BLACK

 a=b=c=0
  a ? b:c
  a ?b:c

  p(a ? b:c)
  p(a ?b:c)


p~4
p:f
p(~4){}
p(:f){}
h={}
h.default=:foo

p def (h="foobar").default= v; p @v=v;v end
p h

p h.default=:b

x, (*y) = [:x, :y, :z]
p x
p y

x, *y = [:x, :y, :z]
p x
p y

x, * = [:x, :y, :z]
p x



p Array("foo\nbar")



p +(4)
p -(4)

p :'\\'

class Foop
  def Foop.bar a,b
    p a,b
  end
end
Foop.bar 1,2
Foop::bar 3,4


class Foop
  def Foop::baz a,b
    p :baz,a,b
  end
end
Foop.baz 5,6
Foop::baz 7,8



without_creating=widgetname=nil
      if without_creating && !widgetname #foo
        fail ArgumentError,
             "if set 'without_creating' to true, need to define 'widgetname'"
      end



=begin disable for now

#class, module, and def should temporarily hide local variables
def mopsdfjskdf arg; arg*2 end
mopsdfjskdf=5
 class C
 p mopsdfjskdf %(3)    #calls method
 end

module M
 p mopsdfjskdf %(4)    #calls method
end

 def d
 p mopsdfjskdf %(5)    #calls method
 end
p d
p mopsdfjskdf %(6)     #reads variable
p proc{mopsdfjskdf %(7)}[] #reads variable

#fancy symbols not supported yet
p %s{symbol}
=end

#multiple assignment test
proc {
  a,b,c,d,e,f,g,h,i,j,k=1,2,3,4,5,6,7,8,9,10,11
  p(b %(c))
  p(a %(c))
  p(k %(c))
  p(p %(c))
}.call


=begin disable for now
p "#{<<kekerz}#{"foob"
zimpler
kekerz
}"


aaa=<<whatnot; p "#{'uh,yeah'
gonna take it down, to the nitty-grit
gonna tell you mother-fuckers why you ain't shit
cause suckers like you just make me strong
whatnot
}"
p aaa

#test variable creation in string inclusion
#currently broken because string inclusions
#are lexed by a separate lexer!
proc {
  p "jentawz: #{baz=200}"
  p( baz %(9))
}.call
=end

=begin ought to work...ruby doesn't like
class A
class B
class C
end
end
end
def A::B::C::d() :abcd end
def A::B::d() :abd end   #this used to work as well... i think

def nil.d=; end #this works
def (;).d=; end
def ().d=; end
p def (p h="foobar";).default= v; p @v=v;v end
p def (p h="foobar";h).default= v; p @v=v;v end

p~4{}
p:f{}
p ~4{}
p :f{}

def g a=:g; [a] end
g g g  #this works
g *g   #this works
g *g g #this doesn't

[nil,p 5]
"foo"+[1].join' '

class Fook
def foo; end


#these work:
(not true)
p(!true) #etc
(true if false) #etc
(true and false) #etc
(undef foo)
(alias bar foo)
(BEGIN{p :yyy})

#these don't:
p(not true)
p(true if false) #etc
p(true and false) #etc
p(undef foo)
p(alias bar foo)
p(BEGIN{p :yyy})
end

=end

proc {
}

p "#{<<foobar3}"
bim
baz
bof
foobar3

def func
  a,b,* = [1,2,3,4,5,6,7,8]
  p a,b
  a,b, = [1,2,3,4,5,6,7,8]
  p a,b

  a,b = [1,2,3,4,5,6,7,8]
  p a,b
  a,*b = [1,2,3,4,5,6,7,8]
  p a,b

  a,b,*c=[1,2,3,4,5,6,7,8]
  a,b,* c=[1,2,3,4,5,6,7,8]
end
func


p( %r{\/$})
p( %r~<!include:([\/\w\.\-]+)>~m)

p <<end
#{compile_body}\
#{outvar}
end





proc {
  h={:a=>(foo=100)}
  p( foo %(5))
}.call


p "#{<<foobar3}"
bim
baz
bof
foobar3

p "#{<<foobar2
bim
baz
bof
foobar2
}"

p <<one ; p "#{<<two}"
1111111111111111
fdsgdfgdsfffff
one
2222222222222222
sdfasdfasdfads
two
p "#{<<foobar0.each('|'){|s| '\nthort: '+s} }"
jbvd|g4543ghb|!@G$dfsd|fafr|e
|s4e5rrwware|BBBBB|*&^(*&^>"PMK:njs;d|

foobar0

p "#{<<foobar1.each('|'){|s| '\nthort: '+s}
jbvd|g4543ghb|!@G$dfsd|fafr|e
|s4e5rrwware|BBBBB|*&^(*&^>"PMK:njs;d|

foobar1
}"

def foo(a=<<a,b=<<b,c=<<c)
jfksdkjf
dkljjkf
a
kdljfjkdg
dfglkdfkgjdf
dkf
b
lkdffdjksadhf
sdflkdjgsfdkjgsdg
dsfg;lkdflisgffd
g
c

   a+b+c

end
p foo



$a=1
@b=2
@@c=3
p "#$a #@b #@@c #{$a+@b+@@c}"
p "\#$a \#@b \#@@c \#{$a+@b+@@c}"
p '#$a #@b #@@c #{$a+@b+@@c}'
p '\#$a \#@b \#@@c \#{$a+@b+@@c}'
p %w"#$a #@b #@@c #{$a+@b+@@c}"
p %w"\#$a \#@b \#@@c \#{$a+@b+@@c}"
p %W"#$a #@b #@@c #{$a+@b+@@c}"
p %W"\#$a \#@b \#@@c \#{$a+@b+@@c}"
p %Q[#$a #@b #@@c #{$a+@b+@@c}]
p %Q[\#$a \#@b \#@@c \#{$a+@b+@@c}]
p `echo #$a #@b #@@c #{$a+@b+@@c}`
p `echo \#$a \#@b \#@@c \#{$a+@b+@@c}`
p(/#$a #@b #@@c #{$a+@b+@@c}/)
#p(/\#$a \#@b \#@@c \#{$a+@b+@@c}/) #moved to w.rb

class AA; class BB; class CC
FFOO=1
end end end

p AA::BB::CC::FFOO

compile_body=outvar='foob'

if false
 method_src = c.compile(template, (HtmlCompiler::AnyData.new)).join("\n") +
    "\n# generated by PartsTemplate::compile_partstemplate at #{Time.new}\n"
 rescu -1
end

  p('rb_out', 'args', <<-'EOL')
    regsub -all {!} $args {\\!} args
    regsub -all "{" $args "\\{" args
    if {[set st [catch {ruby [format "TkCore.callback %%Q!%s!" $args]} ret]] != 0} {
        return -code $st $ret
    } {
        return $ret
    }
  EOL

def add(*args)
   self.<<(*args)
end



val=%[13,17,22,"hike", ?\s]
    if val.include? ?\s
      p val.split.collect{|v| (v)}
    end
p "#{}"
p "#(1)"
class Hosts
end
class DNS < Hosts
end
def intialize(resolvers=[Hosts.new, DNS.new]) end
def environment(env = File.basename($0, '.*')) end

def ssssss &block
end
def params_quoted(field_name, default)
  if block_given? then yield field_name else default end
end
def ==(o) 444 end
def String.ffff4() self.to_s+"ffff" end

p *[]
for i in \
[44,55,66,77,88] do p i**Math.sqrt(i) end

#(
for i in if
false then foob12345; else [44,55,66,77,88] end do p i**Math.sqrt(i) end
#)
(
for i in if false then
foob12345; else [44,55,66,77,88] end do p i**Math.sqrt(i) end

c=j=0
until while j<10 do j+=1 end.nil? do p 'pppppppppp' end
for i in if false then foob12345;
else [44,55,66,77,88] end do p i**Math.sqrt(i) end

for i in if false then foob12345; else
[44,55,66,77,88] end do p i**Math.sqrt(i) end


for i in (c;
[44,55,66,77,88]) do p i**Math.sqrt(i) end
)
(

for i in (begin
[44,55,66,77,88] end) do p i**Math.sqrt(i) end

for i in if false then foob12345; else
[44,55,66,77,88] end do p i**Math.sqrt(i) end

for i in (

[44,55,66,77,88]) do p i**Math.sqrt(i) end

for i in (
[44,55,66,77,88]) do p i**Math.sqrt(i) end

)


def yy;yield end

block=proc{p "blah  blah"}

yy &block
p(1.+1)
p pppp

module M66
p(proc do
   p=123
end.call)

p proc {
   p=123
}.call

p def pppp
   p=123
end
p module Ppp
   p=123
end
p class Pppp < String
   p=123
end
end

    def _make_regex(str) /([#{Regexp.escape(str)}])/n end
p _make_regex("8smdf,34rh\#@\#$%$gfm/[]dD")


p "#$a #@b #@@c

d e f
#$a #@b #@@c
"

p "\""

a=a.to_s
class <<a
  def foobar
     self*101
  end
  alias    eql?    ==
end

p a.foobar

p(/^\s*(([+-\/*&\|^]|<<|>>|\|\||\&\&)=|\&\&|\|\|)/)
p(:%)
p( { :class => class_=0})
p cls_name = {}[:class]


p foo
p "#{$!.class}"
p :p
p(:p)
p(:"[]")
p :"[]"
p("\\")
p(/\\/)
p(/[\\]/)
p 0x80
p ?p
p 0.1
p 0.8
p 0.9
p(-1)
p %/p/
p %Q[<LI>]
i=99
p %Q[<LI><A HREF="#{i[3]}.html\##{i[4]}">#{i[0]+i[1]+(i[2])}</A>\n]
p(:side=>:top)
p %w[a b c
     d e f]
p %w[a b c\n
     d e f]
p %w[\\]
p %w[\]]
p :+
p 99 / 3

a=99;b=3
p 1+(a / b)
p %Q[\"]
p %Q[ some [nested] text]

if false
     formatter.format_element(element) do
       amrita_expand_and_format1(element, context, formatter)
     end
end
if false
 ret = <<-END
 @@parts_template = #{template.to_ruby}
 def parts_template
   @@parts_template
 end

 #{c.const_def_src.join("\n")}
 def amrita_expand_and_format(element, context, formatter)
   if element.tagname_symbol == :span and element.attrs.size == 0
     amrita_expand_and_format1(element, context, formatter)
   else
     formatter.format_element(element) do
       amrita_expand_and_format1(element, context, formatter)
     end
   end
 end

 def amrita_expand_and_format1(element, context, formatter)
   #{method_src}
 end
 END
 j=55
end

p '
'
p '\n'
p "
"
p "\n"
p %w/
/
p %w/\n/

p %W/
/
p %W/\n/
p(/
/)
p(/\n/)
p proc {
  p `
  `
  p `\n`
}



p(%r[foo]i)
#breakpoint
p <<stuff+'foobar'.tr('j-l','d-f')
"more stuff"
12345678
the quick brown fox jumped over the lazy dog
stuff

=begin doesn't work
p <<stuff+'foobar'.tr('j-l','d-f')\
+"more stuff"
12345678
the quick brown fox jumped over the lazy dog
stuff
=end

p ENV["AmritaCacheDir"]
p <<-BEGIN + <<-END
          def element_downcase(attributes = {})
        BEGIN
          end
        END



p <<ggg; def
kleegarts() p 'kkkkkkk' end
dfgdgfdf
ggg
koomblatz!() p 'jdkfsk' end

koomblatz!

p f = 3.7517675036461267e+17
p $10
p $1001
p( <<end )
nine time nine men have stood untold.
end

def jd_to_wday(jd) (jd + 1) % 7 end
p jd_to_wday(98)


p    pre = $`
=begin
=end

p <<"..end .."
cbkvjb
vb;lkxcvkbxc
vxlc;kblxckvb
xcvblcvb
..end ..

p $-j=55

def empty() end

p <<a
dkflg
flk
a

label='label';tab=[1,2,3]
      p <<S
#{label} = arr = Array.new(#{tab.size}, nil)
str = a = i = nil
idx = 0
clist.each do |str|
  str.split(',', -1).each do |i|
    arr[idx] = i.to_i unless i.empty?
    idx += 1
  end
end

S
def printem1 a,b,c
   p(a +77)
   p(b +77)
   p(c +77)
end

def foobar() end
def foobar2
end

def printem0(a)
   p(a +77)
end
def printem0(a,b,c)
   p(a +77)
   p(b +77)
   p(c +77)
end
def printem2 a,b,c; p(a +77); p(b +77); p(c +77) end
def three() (1+2) end

def d;end
def d()end
def d(dd)end

def printem a,b,c
   p a;p b;p c
   p(a +77)
   p(b %(0.123))
end
printem 1,2,3

a=1
p(a +77)

def hhh(a=(1+2)) a end



END {
  p "bye-bye"
}


p <<here
where?
here
p <<-what
     ? that's
  what
p proc{||}
for i in if false
foob12345; else [44,55,66,77,88] end do p i**Math.sqrt(i) end
p "\v"
c=0
      while c == /[ \t\f\r\13]/; end







