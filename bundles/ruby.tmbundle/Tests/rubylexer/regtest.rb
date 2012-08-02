#!/usr/bin/ruby -w -d
require "reg"
require "regarray"
require "reglogic"
require "reghash"
require "regvar"
require "assert"
require 'getoptlong'

#require 'test/unit'
class TC_Reg #< Test::Unit::TestCase
  class <<self


  def randsym
    as=Symbol.all_symbols
    as[rand as.size]
  end

  def makelendata(num=20,mask=0b11111111111,mischief=false)
    result=[]
    (1..num).each do
      begin type=rand(11) end until 0 != mask&(1<<type)
      len=type==0 ? 0 : rand(4)

      result<<case type
        when 0    then [0]
        when 1 then [len]+(1..len).map{randsym}
        when 2 then (1..len).map{randsym}+[-len]
        when 3 then (1..len).map{randsym}+["infix#{len}"]+(1..len).map{randsym}
        when 4
          [:Q] +
            (1..len).map{randsym}.delete_if {|x|:Q==x} +
            (1..rand(4)).map{randsym}.delete_if {|x|:Q==x} +
          [:Q]
        when 5
          [:Q] +
            (1..len).map{randsym}.delete_if {|x|:Q==x} +
            [:'\\', :Q] +
            (1..rand(4)).map{randsym}.delete_if {|x|:Q==x} +
          [:Q]

        when 6
          [:q]+(1..len).map{randsym}.delete_if {|x|:q==x}+[:q]

        when 7
          [:begin]+
            (1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
          [:end]

        when 8
          [:begin]+
            (1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            [:'\\', 0==rand(1) ? :begin : :end] +
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
          [:end]

        when 9
          [:begin]+
            (1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            [:begin]+(1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +[:end]+
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
          [:end]

        when 10
          [:begin]+
            (1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            [:'\\', 0==rand(1)? :begin : :end] +
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            [:begin]+(1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +[:end]+
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
          [:end]
      end
    end
    mischief and result.insert(rand(result.size),mischief)
    return result
  end


  def test_reg
     lenheadalts=-[0]|-[1,OB]|-[2,OB*2]|-[3,OB*3]|-[4,OB*4]
     lenheadlist=lenheadalts+1

     lenheaddata=[0,0,0,1,:foo,4,:foo,:bar,:baz,:zork,3,:k,77,88]
     lenheaddataj=lenheaddata+[:j]


     #not used yet:
     lentailalts=-[OB,-1]|-[OB*2,-2]|-[OB*3,-3]|-[OB*4,-4]
     lentaildata=lenheaddata.reverse.map {|x| Integer===x ? -x : x }
     infixalts=-[OB,"infix1",OB]|-[OB*2,'infix2',OB*2]|
               -[OB*3,'infix3',OB*3]|-[OB*4,'infix4',OB*4]


     qq=-[:q, ~(:q.reg)+0, :q]
     _QQ=-[:Q, ( ~/^[Q\\]$/.sym | -[:'\\',OB] )+0, :Q]


     be=-[:begin, (
           ~/^(begin|end|\\)$/.sym |
           -[:'\\',OB] |
           innerbe=Reg.const
         )+0, :end]
     innerbe.set! be

     lh_or_qq=lenheadalts|qq|_QQ
     lhqqbe=lh_or_qq|be








#broken:
#eat_unworking=<<'#end unworking'
     a=[:foo]*4
     x=(OB*2*(1..2)).mmatch(a,2)
     assert x.next_match(a,2)==[[[[:foo, :foo]]], 2]
     assert x.next_match(a,2)==nil

     assert_eee OB*(1..2)*2,[:foo]*2

     a=[:foo]*3
     x=(OB*(1..2)*2).mmatch(a,0)
     assert x.next_match(a,0)==
       [[ [[:foo, :foo]], [[:foo]] ], 3]
     assert x.next_match(a,0)==
       [[ [[:foo]], [[:foo, :foo]] ], 3]
     assert x.next_match(a,0)==
       [[ [[:foo]], [[:foo]] ], 2]
     assert x.next_match(a,0).nil?

     a=[:foo]*6
     x=(OB*2*(1..2)*2).mmatch(a,0)
     assert x.next_match(a,0)==
       [[ [[[:foo, :foo]], [[:foo, :foo]]], [[[:foo, :foo]]] ], 6]
     assert x.next_match(a,0)==
       [[ [[[:foo, :foo]]], [[[:foo, :foo]], [[:foo, :foo]]] ], 6]
     assert x.next_match(a,0)==
       [[ [[[:foo, :foo]]], [[[:foo, :foo]]] ], 4]
     assert x.next_match(a,0).nil?

$RegTraceEnable=true
     assert_eee Reg[OB*2*(1..2)*2], [:foo]*6
     assert_eee Reg[OB*2*(1..2)*2, OB-1], [:foo]*7
     assert_eee Reg[OB*2*(1..2)*2], [:foo]*8
     assert_eee Reg[OB*2*(1..2)*2], [:foo]*4
     assert_eee Reg[OB*(2..3)*(1..2)*2], [:foo]*4
     assert_eee Reg[OB*(2..3)*(2..3)*(1..2)], [:foo]*4
     assert_eee Reg[OB*(2..2)*(2..3)*(2..3)], [:foo]*8
     assert_eee Reg[OB*(2..3)*(2..2)*(2..3)], [:foo]*8

     assert_eee Reg[OB*(2..3)*(2..3)*2], [:foo]*8
     assert_eee Reg[OB*(2..3)*(2..3)*(2..3)], [:foo]*8
     assert_eee Reg[OB+2+2+2], [:foo]*8
     assert_eee Reg[OB+2+2+2], [:foo]*9
     assert_ene Reg[:foo.reg*(2..3)*(2..3)*2], [:foo]*7

     assert(!(Reg[OB*1*(1..2)]===[:f]).first.empty?)
     #btracing monsters
     0.upto(5) {|i|
       assert_ene Reg[OB+1+3+2], [:f]*i }
     6.upto(16){|i| assert_eee Reg[OB+1+3+2], [:f]*i }

     assert_ene Reg[OB+2+3+2], [:f]*11
     assert_eee Reg[OB+2+3+2], [:f]*12
     assert_ene Reg[OB+2+3+3], [:f]*17
     assert_eee Reg[OB+2+3+3], [:f]*18
     assert_ene Reg[OB+3+3+3], [:f]*26
     assert_eee Reg[OB+3+3+3], [:f]*27
     assert_ene Reg[OB+4+4+4], [:f]*63
     assert_eee Reg[OB+4+4+4], [:f]*64
     assert_ene Reg[OB+2+2+2+2], [:f]*15
     assert_eee Reg[OB+2+2+2+2], [:f]*16
     assert_ene Reg[OB+2+2+2+2+2+2+2+2], [:foo]*255
     assert_eee Reg[OB+2+2+2+2+2+2+2+2], [:foo]*256

     aaa_patho=+[-[/^a/]|-[/^.a/, OB]|-[/^..a/, OB*2]]
     assert_eee aaa_patho, ["aaa"]*200



     assert_ene Reg[OB+1+2+2], [:f]*3
     assert_ene Reg[OB+2+1+2], [:f]*3
     assert_eee Reg[OB+2+1+2], [:f]*4
     assert_ene Reg[OB+2+2+2], [:f]*7
     assert_eee Reg[OB+2+2+2], [:f]*8

     assert_ene Reg[OB+2+2+3], [:f]*11
     assert_eee Reg[OB+2+2+3], [:f]*12
     assert_eee Reg[OB+2+2+3], [:f]*16

     assert_ene Reg[5.reg+1+3+2], [6]+[5]*5
     assert_ene Reg[5.reg+1+3+2], [5]+[6]+[5]*4
     assert_ene Reg[5.reg+1+3+2], [5]*2+[6]+[5]*3
     assert_ene Reg[5.reg+1+3+2], [5]*3+[6]+[5]*2
     assert_ene Reg[5.reg+1+3+2], [5]*4+[6,5]
     assert_ene Reg[5.reg+1+3+2], [5]*5+[6]

     assert_ene Reg[OB+1+3+2], [6]+[5]*5
     assert_ene Reg[OB+1+3+2], [5]+[6]+[5]*4
     assert_ene Reg[OB+1+3+2], [5]*2+[6]+[5]*3
     assert_ene Reg[OB+1+3+2], [5]*3+[6]+[5]*2
     assert_ene Reg[OB+1+3+2], [5]*4+[6,5]
     assert_ene Reg[OB+1+3+2], [5]*5+[6]


     assert_eee Reg[5.reg+1+3+2], [5]*6
     assert_ene Reg[5.reg+2+2+2], [5]*8+[6]
#end unworking

#working:
     assert_ene Reg[OB*(2..2)*(2..3)*(2..3)], [:foo]*7
     assert_ene Reg[OB*(2..3)*(2..2)*(2..3)], [:foo]*7
     assert_ene Reg[OB*(1..3)*(2..3)*2], [:foo]*3
     assert_ene Reg[OB*(2..3)*(1..3)*2], [:foo]*3
     assert_ene Reg[OB*(2..3)*(2..3)*(1..2)], [:foo]*3

     assert_ene Reg[OB*(2..3)*(2..3)*2], [:foo]*7
     assert_ene Reg[OB*(2..3)*(2..3)*(2..3)], [:foo]*7
     assert_ene Reg[OB+2+2+2], [:foo]*7


     assert_eee Reg[OB*(1..3)*(2..3)*2], [:foo]*4
     assert_eee Reg[OB*2*1*2], [:foo]*4
     assert_eee Reg[OB*1*(1..2)*2], [:foo]*2
     assert_eee Reg[OB*2*(1..2)*1], [:foo]*2
     assert_eee Reg[OB*1*(1..2)*2], [:foo]*3
     assert_ene Reg[OB*2*(1..2)*1], [:foo]*3
     assert_eee Reg[OB*1*(1..2)*2], [:foo]*4
     assert_eee Reg[OB*2*(1..2)*1], [:foo]*4

     a=[:foo]
     x=(:foo.reg-1).mmatch a,0
     assert x.next_match(a,0)==[[[:foo]],1]
     assert x.next_match(a,0)==[[[]],0]
     assert x.next_match(a,0)==nil

     x=(:foo.reg-1).mmatch a,1
     assert x==[[[]],0]

     a=[:foo]
     x=(:foo.reg-1-1).mmatch a,0
     assert x.next_match(a,0)==[[[[:foo]]],1]



     a=[:foo]*3
     x=(:foo.reg*(1..2)).mmatch a,0
     assert x.next_match(a,0)==[[[:foo]*2],2]
     assert x.next_match(a,0)==[[[:foo]],1]
     assert x.next_match(a,0)==nil

     x=(:foo.reg*(1..2)).mmatch a,1
     assert x.next_match(a,0)==[[[:foo]*2],2]
     assert x.next_match(a,0)==[[[:foo]],1]
     assert x.next_match(a,0)==nil

     x=(:foo.reg*(1..2)).mmatch a,2
     assert x==[[[:foo]],1]

     x=(:foo.reg*(1..2)).mmatch a,3
     assert x.nil?

     x=(:foo.reg*(1..2)*(2..3)).mmatch a,0
     assert x.next_match(a,0)==[[[[:foo]*2],[[:foo]]], 3]
     assert x.instance_eval{@ri}==2
     assert x.next_match(a,0)==[[[[:foo]],[[:foo]*2]], 3]
     assert x.instance_eval{@ri}==2
     assert x.next_match(a,0)==[[[[:foo]],[[:foo]],[[:foo]]], 3]
     assert x.instance_eval{@ri}==3
     assert x.next_match(a,0)==[[[[:foo]],[[:foo]]], 2]
     assert x.instance_eval{@ri}==2
     assert x.next_match(a,0)==nil

     x=(:foo.reg*(1..2)*(2..3)).mmatch a,1
     assert x.next_match(a,0)==[[[[:foo]],[[:foo]]], 2]
     assert x.instance_eval{@ri}==2
     assert x.next_match(a,0)==nil

     x=(:foo.reg*(1..2)*(2..3)).mmatch a,2
     assert x.nil?

     x=(:foo.reg*(1..2)*(2..3)).mmatch a,3
     assert x.nil?


     assert((not (:foo.reg*(1..2)*(2..3)*(2..3)).mmatch [:foo]*3,0 ))



     assert_ene Reg[:foo.reg*(1..2)*(2..3)*(2..3)], [:foo]*3
     assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)], [:foo]*4
     assert_ene Reg[OB*(1..2)*(2..3)*(2..3)], [:foo]*3
     assert_eee Reg[OB*(1..2)*(2..3)*(2..3)], [:foo]*4
     assert_ene Reg[OB*(1..2)*(2..3)+2], [:foo]*3
     assert_eee Reg[OB*(1..2)*(2..3)+2], [:foo]*4
     assert_ene Reg[OB*(1..2)+2+2], [:foo]*3
     assert_eee Reg[OB*(1..2)+2+2], [:foo]*4
     assert_ene Reg[OB+1+2+2], [:foo]*3
     assert_eee Reg[OB+1+2+2], [:foo]*4

     assert_eee Reg[5.reg+2+2], [5]*4
     assert_eee Reg[5.reg*(1..2)*(1..2)*(1..2)], [5]
     assert_eee Reg[5.reg*(1..2)*(1..2)*(2..3)], [5]*2
     assert_eee Reg[5.reg*(1..2)*(2..3)*(2..3)], [5]*4
     assert_eee Reg[(5.reg+1)*(2..3)*(2..3)], [5]*4
     assert_eee Reg[(5.reg+1+2)*(2..3)], [5]*4
     assert_eee Reg[5.reg+1+2+2], [5]*4
     assert_eee Reg[OB+3+2], [:f]*6

     assert_ene Reg[-[:foo,:bar]-1], [:bar,:foo]
     assert_ene Reg[-[:foo,:bar]-1], [:baz,:foo,:bar]
     assert_ene Reg[-[:foo,:bar]-1], [:foo,:bar,:baz]
     assert_eee Reg[-[:foo,:bar]-1], [:foo,:bar]
     assert_ene Reg[-[:foo,:bar]-1], [:foo]
     assert_ene Reg[-[:foo,:bar]-1], [:bar]
     assert_ene Reg[-[:foo,:bar]-1], [:baz]
     assert_eee Reg[-[:foo,:bar]-1], []




     assert_eee Reg[(-[-[:p]*(1..2)])], [:p]
     assert_eee Reg[(-[-[:p]*(1..2)])], [:p,:p]
     assert_ene Reg[(-[-[:p]*(1..2)])], [:p,:q]
     assert_ene Reg[(-[-[:p]*(1..2)])], [:q]
     assert_ene Reg[(-[-[:p]*(1..2)])], []
     assert_ene Reg[(-[-[:p]*(1..2)])], [:p,:p, :p]


     assert_eee Reg[OB+1], [:foo,:foo]
     assert_eee Reg[OB+1+1], [:foo,:foo]
     assert_eee Reg[OB+1+1+1], [:foo,:foo]
     assert_eee Reg[OB+1+1+1+1], [:foo,:foo]

     assert_ene Reg[OB+2+3], [:f]*5
     assert_ene Reg[OB+2+2+1], [:f]*3

     assert_eee Reg[lhqqbe+0], [
      :begin, :popen, :"chomp!", :-@, :end, :q, :q,
      :begin, :begin, :end, :end,
      :begin, :MINOR_VERSION, :"public_method_defined?", :"\\", :begin, :umask,
              :debug_print_help, :geteuid, :end,
      :q, :public_methods, :option_name, :MUTEX, :q,
      :begin, :verbose=, :binding, :symlink, :lambda,
              :emacs_editing_mode, :"dst?", :end, 0,
      :begin, :test_to_s_with_iv, :"\\", :begin, :glob, :each_with_index,
              :initialize_copy, :begin, :$PROGRAM_NAME, :end,
              :ELIBACC, :setruid, :"success?", :end,
      :begin, :__size__, :width, :"\\", :begin, :$-a, :"sort!", :waitpid, :end,
      :begin, :Stat, :WadlerExample, :chr, :end,
      :begin, :+, :disable, :abstract,
              :begin, :__size__, :"symlink?", :"dst?", :end, :ljust, :end,
      :begin, :debug_method_info, :matchary, :"\\", :begin, :ftype,
              :thread_list_all, :eof, :begin, :abs, :GroupQueue, :end,
              :"slice!", :ordering=, :end,
      :Q, :"\\", :Q, :ELIBMAX, :GetoptLong, :nlink, :Q,
      :begin, :Fixnum, :waitall, :"enclosed?", :"\\", :begin, :deep_copy,
              :getpgid, :strftime, :end,
      :Q, :close_obj, :Q,
      3, :basic_quote_characters=, :rmdir, :"writable_real?",
      :begin, :test_hello_11_12, :utc_offset, :freeze,
              :begin, :kcode, :egid=, :ARGF, :end,
              :setuid, :lock, :gmtoff, :end,
      :begin, :$FILENAME, :test_tree_alt_20_49,
              :begin, :LOCK_SH, :EL3HLT, :end, :end,
      :Q, :"\\", :Q, :ceil, :remainder, :group_sub, :Q, 0
     ]

if ($Slow||=nil)
     #assert_eee Reg[OB+10+10], [:f]*100 #waaaay too slow
     assert_eee Reg[OB+5+5], [:f]*25
     assert_ene Reg[OB+5+5], [:f]*24
     assert_eee Reg[OB+6+6], [:f]*36
     assert_ene Reg[OB+6+6], [:f]*35
     assert_eee Reg[OB+7+7], [:f]*49 #prolly excessive
     assert_ene Reg[OB+7+7], [:f]*48 #prolly excessive
end

     assert_eee Reg[lhqqbe+0], [ :begin, :"\\", :rand, :end ]
 #breakpoint
     assert_eee +[be], [:begin, :"\\", :"\\", :end]
     assert_eee +[be], [:begin, :"\\", :begin, :end]
     assert_eee +[be], [:begin, :"\\", :end, :end]
     assert_eee +[be], [:begin, :log, :readline, :"\\", :begin, :lh_or_qq, :test_pretty_print_inspect, :@newline, :end]
     assert_eee +[be], [:begin, :lock, :rindex, :begin, :sysopen, :rename, :end, :re_exchange, :on, :end]
     assert_eee +[be], [:begin, :lock, :"\\", :"\\", :begin, :rename, :end, :on, :end]
     assert_eee +[be], [:begin, :begin, :foo, :end, :end]
     assert_eee +[be], makelendata(1,0b11110000000).flatten
     assert_eee +[be], [:begin, :end]
     assert_eee +[be], [:begin, :foo, :end]
     assert_eee +[be], makelendata(1,0b10000000).flatten
     assert_eee Reg[lhqqbe+0], makelendata(1,0b11111110011).flatten
     assert_eee Reg[lhqqbe+0], makelendata(4,0b11111110011).flatten
     assert_eee Reg[lhqqbe+0], makelendata(10,0b11111110011).flatten
     assert_eee Reg[lhqqbe+0], makelendata(20,0b11111110011).flatten

     assert_ene Reg[:foo,OB+1], [:foo]
     assert_ene Reg[OB+1,:foo], [:foo]
     assert_eee Reg[OB+1], [:foo]


     assert_eee Reg[OB+1+1+1+1+1+1+1+1+1+1+1+1+1+1], [:foo]

     assert_ene Reg[OB+1+1+1+1], []
     assert_eee Reg[OB+1+1+1+1], [:foo,:foo]
     assert_ene Reg[OB+2], [:foo]
     assert_ene Reg[OB+2+2], [:foo]*3
     assert_ene Reg[OB+2+2+1], [:foo]*3
     assert_ene Reg[OB+2+1+2], [:foo]*3


     assert_eee Reg[-[1,2]|3], [1,2]
     assert_eee Reg[-[1,2]|3], [3]
     assert_ene Reg[-[1,2]|3], [4]
     assert_ene Reg[-[1,2]|3], [2]
     assert_ene Reg[-[1,2]|3], [1,3]

     assert_eee Reg[lenheadlist], [1, :__id__]
     assert_eee Reg[(-[0]|-[1,OB]|-[2,OB*2])*1], [2, :p, :stat]
     assert_eee Reg[(-[2,OB*2])-1], [2, :p, :stat]
     assert_eee Reg[(-[OB])*(1..2)], [1, :p]

     assert_eee Reg[(-[-[:p]*(1..2)])], [:p]
     assert_eee Reg[(-[-[:p]])*(1..2)], [:p]
     assert_eee Reg[(-[-[OB]])*(1..2)], [:p]
     assert_eee Reg[(-[OB*1])*(1..2)], [:p]
     assert_eee Reg[(-[1,OB*1])*(1..2)], [1, :p]
     assert_eee Reg[(-[2,OB*2])*(1..2)], [2, :p, :stat]
     assert_eee Reg[(-[0]|-[1,OB]|-[2,OB*2])*(1..2)], [2, :p, :stat]
     assert_eee Reg[(-[0]|-[1,OB]|-[2,OB*2])+1], [2, :p, :stat]
     assert_eee Reg[lenheadlist], [2, :p, :stat]
     assert_eee Reg[lenheadlist], [2, :p, :stat, 1, :__id__]
     assert_eee Reg[lenheadlist], [2, :p, :stat, 0, 1, :__id__, 0, 0]
     assert_eee Reg[lenheadlist], lenheaddata
     assert_ene Reg[lenheadlist], lenheaddataj
     assert_eee +[lh_or_qq+0], lenheaddata
     assert_eee +[lh_or_qq+0], lenheaddata+[:q, :foo, :bar, :baz, :q]

     assert_eee Reg[lenheadlist], [0]
     assert_eee Reg[lenheadlist], makelendata(1,0b11).flatten
     assert_eee Reg[lenheadlist], makelendata(5,0b11).flatten
     assert_eee Reg[lenheadlist], makelendata(10,0b11).flatten
     assert_eee Reg[lenheadlist], makelendata(20,0b11).flatten
     assert_ene Reg[lenheadlist], makelendata(20,0b11).flatten+[:j]
     assert_ene Reg[lenheadlist], [:j]+makelendata(20,0b11).flatten+[:j]
     assert_ene Reg[lenheadlist], [:j]+makelendata(20,0b11).flatten

     assert_ene Reg[lenheadlist], makelendata(20,0b11,:j).flatten
     assert_eee +[lh_or_qq+0], makelendata(20,0b11).flatten
     assert_eee +[lh_or_qq+0], makelendata(20,0b1000011).flatten
     assert_ene +[lh_or_qq+0], makelendata(20,0b1000011).flatten+[:j]
     assert_ene +[lh_or_qq+0], [:j]+makelendata(20,0b1000011).flatten+[:j]
     assert_ene +[lh_or_qq+0], [:j]+makelendata(20,0b1000011).flatten



     t=(1..2)
     assert_eee Reg[OB*t*t*t*t], [:foo]*16
     assert_ene Reg[OB*t*t*t*t], [:foo]*17
     assert_eee Reg[5.reg*t], [5]
     assert_eee Reg[5.reg*t*1], [5]
     assert_eee Reg[5.reg*1*t], [5]
     assert_eee Reg[5.reg*t*t], [5]
     assert_eee Reg[5.reg*t*t*t], [5]
     assert_eee Reg[5.reg*t*t*t*t], [5]
     assert_eee Reg[5.reg+1+1+1], [5]
     assert_eee Reg[5.reg+1+1+1+1], [5]
     assert_eee Reg[OB+1+1+1], [:foo]
     assert_eee Reg[OB+1+1+1+1], [:foo]
     assert_eee Reg[OB+2], [:foo]*2
     assert_eee Reg[OB+2+2], [:foo]*4



     #btracing monsters:
     assert_eee Reg[OB*2], [:foo]*2
     assert_eee Reg[OB*2*2], [:foo]*4
     assert_eee Reg[OB*2*2*2*2], [:foo]*16
     assert_eee Reg[OB*2*2*2*2*2*2*2*2], [:foo]*256
     assert_eee Reg[OB-2-2-2-2-2-2-2-2], [:foo]*256



     assert_ene Reg[OB-0], [1]
     assert_eee Reg[OB+0], [1]
     assert_eee Reg[OB-1], [1]
     assert_eee Reg[OB+1], [1]
     assert_eee Reg[OB-2], [1,2]
     assert_eee Reg[OB+2], [1,2]

     assert_eee Reg[OB], [1]
     assert_eee Reg[OB*1], [1]
     assert_eee Reg[OB*2], [1,2]
     assert_eee Reg[OB*4], [1,2,3,4]

     abcreg=Reg[OBS,:a,:b,:c,OBS]
     assert_eee abcreg, [:a,:b,:c,7,8,9]
     assert_eee abcreg, [1,2,3,:a,:b,:c,7,8,9]

     assert_eee abcreg, [1,2,3,:a,:b,:c]
     assert_eee abcreg, [:a,:b,:c]

     assert_ene abcreg, [1,2,3,:a,:b,:d]
     assert_ene abcreg, [1,2,3,:a,:d,:c]
     assert_ene abcreg, [1,2,3,:d,:b,:c]

     assert_ene abcreg, [1,2,3]
     assert_ene abcreg, [1,2,3,:a]
     assert_ene abcreg, [1,2,3,:a,:b]

     assert_eee Reg[:a, OB+0, :b, :b, :b, :b, :b], [:a, 1,1,1,1,1,1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB+0, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB+0, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b, :b]

     assert_eee Reg[:a, OB+1, :b, :b, :b, :b, :b], [:a, 1,1,1,1,1,1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB+1, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b, :b]
     assert_ene Reg[:a, OB+1, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b, :b]

     assert_ene Reg[:a, OB-1, :b, :b, :b, :b, :b], [:a, 1,1,1,1,1,1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB-1, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB-1, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b, :b]

     assert_ene Reg[:a, OB-0, :b, :b, :b, :b, :b], [:a, 1,1,1,1,1,1, :b, :b, :b, :b, :b]
     assert_ene Reg[:a, OB-0, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB-0, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b, :b]

     assert_eee Reg[-[OB*2]], [99, 99]  #di not right in top level
     assert_eee Reg[-[-[-[-[-[OB*2]]]]]], [99, 99]  #di not right in top level?
     assert_eee Reg[-[-[-[-[-[OB*1]]]]]], [99]  #di not right in top level?
     #RR[RR[[RR[RR[RR[RR[99,99]]]]]]]
     assert_eee Reg[OB*1], [:foo]
     assert_eee Reg[-[OB]], [88]
     assert_ene Reg[-[0]], [88]
     assert_eee Reg[-[0]], [0]
     assert_eee Reg[-[OB*1]], [:foo]
     assert_eee Reg[OB*1*1], [:foo]
     assert_eee Reg[OB*1*1*1*1*1*1*1*1*1*1*1*1*1*1], [:foo]
     assert_eee Reg[OB-1-1-1-1-1-1-1-1-1-1-1-1-1-1], [:foo]
     assert_eee Reg[-[2,OB*2]], [2, 99, 99]

     assert_eee RegMultiple, -[0]|-[1,2]
     assert( (-[0]|-[1,2]).respond_to?( :mmatch))

     assert_eee Reg[-[0],OBS], lenheaddataj
     assert_eee Reg[-[0]|-[1,OB],OBS], lenheaddataj
     assert_eee Reg[-[0]|-[1,OB]|-[2,OB*2],OBS], lenheaddataj
     assert_eee Reg[-[0]|-[1,OB]|-[2,OB*2]|-[3,OB*3],OBS], lenheaddataj
     assert_eee Reg[-[0]|-[1,OB]|-[2,OB*2]|-[3,OB*3]|-[4,OB*4],OBS], lenheaddataj



     assert_eee Reg(:a=>:b), {:a=>:b}  #=> true
     assert_ene Reg(:a=>:b), {:a=>:c}  #=> false
     assert_ene Reg(:a=>:b), {}  #=> false
     h={}
     h.default=:b
     assert_eee Reg(:a=>:b), h  #=> true

     assert_eee Reg(/^(a|b)$/=>33), {"a"=>33}  #=> true
     assert_eee Reg(/^(a|b)$/=>33), {"b"=>33}  #=> true
     assert_ene Reg(/^(a|b)$/=>33), {"a"=>133}  #=> false
     assert_ene Reg(/^(a|b)$/=>33), {"b"=>133}  #=> false

     assert_ene Reg(/^(a|b)$/=>33), {"c"=>33}  #=> false

     assert_eee Reg(/^(a|b)$/=>33), {"a"=>33,"b"=>33}  #=> true
     assert_ene Reg(/^(a|b)$/=>33), {"a"=>33,"b"=>133}  #=> false
     assert_ene Reg(/^(a|b)$/=>33), {"a"=>133,"b"=>33}  #=> false
     assert_ene Reg(/^(a|b)$/=>33), {"a"=>133,"b"=>133}  #=> false


     assert_eee Reg("a"=>33)|{"b"=>33}, {"a"=>33,"b"=>33}  #=> true
     assert_eee Reg("a"=>33)|{"b"=>33}, {"a"=>33,"b"=>133}  #=> true
     assert_ene Reg("a"=>33)|{"b"=>33}, {"a"=>133,"b"=>33}  #=> false
     assert_ene Reg("a"=>33)|{"b"=>33}, {"a"=>133,"b"=>133}  #=> false

     assert_eee Reg("a"=>33)|{"b"=>33}, {"b"=>33}  #=> true

     assert_eee Reg(:a.reg|:b => 44), {:a => 44}  #=> true
     assert_eee Reg(:a.reg|:b => 44), {:b => 44}  #=> true
     assert_ene Reg(:a.reg|:b => 44), {:a => 144}  #=> false
     assert_ene Reg(:a.reg|:b => 44), {:b => 144}  #=> false

     print "\n"
  end

  def assert_eee(left,right,message='assert_eee failed')
    assert(
      left===right,
      message+" left=#{left.inspect}  right=#{right.inspect}"
    )
    print ".";$stdout.flush
  end

  def assert_ene(left,right,message='assert_ene failed')
    assert(
     !(left===right),
     message+" left=#{left.inspect}  right=#{right.inspect}"
    )
    print ",";$stdout.flush
  end
end
end
     srand;seed=srand

     opts=GetoptLong.new(["--seed", "-s", GetoptLong::REQUIRED_ARGUMENT])
     opts.each{|opt,arg|
       opt=='--seed' or raise :impossible
       seed=arg
     }

     print "random seed is #{seed}\n"
     srand seed


TC_Reg.test_reg
