=begin
  You should run this script with ruby >= 2.3
  And also have these gems installed: prawn, prawn-table, rmagick
  Here is a simple guide to have all these set in os x (high sierra):

  ```
    brew install imagemagick@6
    brew install pkg-config
    export PKG_CONFIG_PATH=/usr/local/opt/imagemagick@6/lib/pkgconfig
    gem install rmagick
    gem install prawn
    gem install prawn-table
  ```

  Then you can run: ruby autoDLD.rb
  If there is still some problem, also try to brew link imagemagick@6.
=end

require 'prawn'
require 'prawn/table'
require 'rmagick'

class Lab1
  def initialize
    puts "Name of project:"
    @name = gets.strip

    puts "Number of bits of input:"
    @n = gets.to_i

    raise "Number of bits must be greater than 1" if @n < 2
    raise "Oops, the output file will be too large for more than 9 bits" if @n > 9

    puts "Insert each element that is supposed to evaluate to true, seperated by space or comma:"
    @t = gets.split(/[\s,.;]+/).map(&:to_i).uniq

    raise "Everything set to false is trivial" if @t.empty?
    raise "Everything set to true is trivial" if @t.size == 1 << @n
    raise "Negative values are not supported" if @t.min < 0
    raise "#{@n} bits cannot store value #{@t.max}" if 1 << @n <= @t.max

    generate_solution
  end

  def _generate_solution t # O(4**n)
    ht = t.zip(0...t.size).to_h

    vis = [false] * 3**@n
    pis = [] # prime implicants
    (0...3**@n).sort_by { |s|
      c = 0
      until s == 0
        c += 1 if s % 3 == 2
        s /= 3
      end
      -c
    } .each do |s| # 01?
      next if vis[s]
      ts, tt, ss, qs = s, 0, 0, []
      @n.times do |i|
        case ts % 3 
        when 1 then ss |= 1 << i; tt += 3**i
        when 2 then qs << i
        end
        ts /= 3
      end
      sss = []
      next unless (0...1 << qs.size).all? do |qcs|
        ns = ss
        qs.size.times { |i| ns |= 1 << qs[i] if qcs >> i & 1 == 1 }
        sss << ns
        ht.include? ns
      end
      (0...3**qs.size).each do |qcs|
        ns = tt
        qs.size.times { |i| ns += qcs % 3 * 3**qs[i]; qcs /= 3 }
        vis[ns] = true
      end
      pis << [s, *sss]
    end

    cover_idx = [-1] * 2**@n
    pis.size.times do |i|
      pis[i][1..-1].each do |ns|
        case cover_idx[ns]
        when -1 then cover_idx[ns] = i
        else cover_idx[ns] = -2
        end
      end
    end

    @solution = cover_idx.select { |x| x >= 0 } .uniq
    covered = [false] * 2**@n
    @solution.each do |i|
      pis[i][1..-1].each { |ns| covered[ns] = true }
    end

    pis.size.times do |i|
      if pis[i][1..-1].any? { |ns| !covered[ns] }
        @solution << i
        pis[i][1..-1].each { |ns| covered[ns] = true }
      end
    end

    fa = (0...@solution.size).to_a
    find_anc = ->(x) { fa[x] == x ? x : fa[x] = find_anc[fa[x]] }
    get_dist = ->(a, b) do 
      d = 0
      @n.times do
        x, y = a % 3, b % 3
        if x < 2 && y < 2
          if x != y
            d += 1
            return d if d == 2
          end
        end
        a, b = a / 3, b / 3
      end
      d
    end
    dist = (0...@solution.size).map { |i| (0...@solution.size).map { |j| i < j ? get_dist[pis[@solution[i]][0], pis[@solution[j]][0]] : 2 } }
    (0...@solution.size).each do |i|
      (i + 1...@solution.size).each do |j|
        fa[find_anc[i]] = find_anc[j] if dist[i][j] == 0
      end
    end

    antihazard = []
    (0...@solution.size).each do |i|
      (i + 1...@solution.size).each do |j|
        if dist[i][j] == 1 && find_anc[i] != find_anc[j]
          get_ah = ->(a, b) do
            r = 0
            @n.times do |k|
              x, y = a % 3, b % 3
              x, y = y, x if y < x
              if x == 0 && y == 1
                r += 2 * 3**k
              else
                r += 3**k if x == 1
              end
              a, b = a / 3, b / 3
            end
            r
          end
          antihazard << get_ah[pis[@solution[i]][0], pis[@solution[j]][0]]
          fa[find_anc[i]] = find_anc[j]
        end
      end
    end

    trit2prod = ->(s) do
      [].tap do |r|
        @n.times { |i| r << "#{?! if s % 3 == 0}#{i}" if s % 3 < 2; s /= 3 }
        r += r if r.size == 1 # NOTE: AND gate can't accept only one input, right?
      end
    end

    @solution = @solution.map { |i| trit2prod[pis[i][0]] } + antihazard.uniq.map { |h| trit2prod[h] }
  end
  
  def generate_solution
    @_solution = _generate_solution(@t)
    # @_solution_n = _generate_solution((0...1 << @n).to_a - @t)
    # @solution = @_solution_n.size < @_solution.size ? [:neg] + @_solution_n : [:pos] + @_solution
    @solution = [:pos] + @_solution
  end

  def render_kmap # NOTE: negation-optimize is not considered
    @covered_by = [""] * (1 << @n)
    (1...@solution.size).each do |i|
      s = 0
      h = (0...@n).zip(0...@n).to_h
      @solution[i].each do |str|
        neg, idx = !str.match(/!/).nil?, str.match(/\d+/)[0].to_i
        s |= 1 << idx unless neg
        h.delete(idx)
      end
      h = h.keys
      (0...1 << h.size).each do |ss|
        ns = s
        h.size.times { |j| ns |= 1 << h[j] if ss >> j & 1 == 1 }
        @covered_by[ns] += ', ' unless @covered_by[ns].empty?
        @covered_by[ns] += i.to_s
      end
    end
    Prawn::Document.generate("#{@name}_kmap.pdf") do |pdf|
      pdf.font "/Library/Fonts/Arial Italic.ttf"
      generate_gray_codes = ->(n) do
        return [?0, ?1] if n == 1
        c = generate_gray_codes[n - 1]
        c.map { |s| ?0 + s } + c.reverse.map { |s| ?1 + s }
      end
      rgc = generate_gray_codes[@n / 2]
      cgc = generate_gray_codes[@n + 1 >> 1]
      b2u = ->(b, f) { (0...b.size).map { |i| (?A.ord + f + i).chr + (b[i] == ?0 ? "\u0305" : "")}}
      data = [[nil, *rgc.map { |s| b2u[s, @n + 1 >> 1].join }]]
      cgc.each do |s|
        data << [b2u[s, 0].join, *(0...1 << @n / 2).map { |i| @covered_by[(s + rgc[i]).to_i(2)] }]
      end
      pdf.table(data)
    end
  end

  def render_circuit
    andc = @solution.size - 1

    f = Magick::Image.new(1280, 720) { self.background_color = "white" }

    agc = [0, 0, 9, 0, 11, 1, 12, 2, 13, 3, 14, 5, 14, 9, 13, 11, 12, 12, 11, 13, 9, 14, 0, 14]
    ogc = [0, 0, 9, 0, 11, 1, 12, 2, 13, 3, 14, 5, 14, 9, 13, 11, 12, 12, 11, 13, 9, 14, 0, 14, 2, 13, 3, 12, 4, 11, 5, 9, 5, 5, 4, 3, 3, 2, 2, 1]

    shift = ->(cords, dx, dy) do
      cords.each_slice(2).to_a.map do |x, y|
        [x + dx, y + dy]
      end.inject(:+)
    end

    scale = ->(cords, xx, yy) do
      cords.each_slice(2).to_a.map do |x, y|
        [x * xx, y * yy]
      end.inject(:+)
    end

    draw = Magick::Draw.new
    draw.annotate(f, 0, 0, 25, 130, 'in') do
      self.pointsize = 36
    end

    draw = Magick::Draw.new
    draw.stroke('black')
    draw.stroke_width(3)
    draw.line(70, 120, 139 + @n * 32, 120)
    draw.draw(f)

    draw = Magick::Draw.new
    draw.stroke('black')
    draw.stroke_width(3)
    draw.line(110, 130, 130, 110)
    draw.draw(f)

    draw = Magick::Draw.new
    draw.annotate(f, 0, 0, 110, 100, "#{@n}") do
      self.pointsize = 36
    end

    @n.times do |i|
      draw = Magick::Draw.new
      draw.annotate(f, 0, 0, 170 + i * 32 - 9, 120 - 10, (?A.ord + i).chr) do
        self.pointsize = 28
      end

      draw = Magick::Draw.new
      draw.stroke('black')
      draw.stroke_width(3)
      draw.line(170 + i * 32, 120, 170 + i * 32, 640)
      draw.draw(f)
    end

    agcxx = 520 / (21 * andc + 7)
    agcgp = agcxx * 7
    agcsx = (170 + (andc - 1) * 32 + 820) / 2 - agcgp
    agcmy = 0
    @solution[1..-1].each.with_index do |a, i|
      draw = Magick::Draw.new
      draw.fill('black')
      draw.polygon(*shift[scale[agc, agcxx, agcxx], agcsx, 120 + agcgp * (3 * i + 1)])
      agcmy += 120 + agcgp * (3 * i + 1) + agcgp
      draw.draw(f)
      ty = 120 + agcgp * (3 * i + 1)
      g = 2 * agcgp / (a.size + 1)
      a.each.with_index do |s, i|
        neg, idx = !s.match(/!/).nil?, @n - 1 - s.match(/\d+/)[0].to_i
        unless neg
          draw = Magick::Draw.new
          draw.line(170 + idx * 32, ty + g * (i + 1), agcsx, ty + g * (i + 1))
          draw.draw(f)
        else
          draw = Magick::Draw.new
          draw.line(170 + idx * 32, ty + g * (i + 1), agcsx - 11, ty + g * (i + 1) - 1)
          draw.draw(f)
          draw = Magick::Draw.new
          draw.fill('none')
          draw.stroke('black')
          draw.stroke_width(2)
          draw.circle(agcsx - 6, ty + g * (i + 1) - 2, agcsx - 2, ty + g * (i + 1) + 2)
          draw.draw(f)
        end
        draw = Magick::Draw.new
        draw.circle(169 + idx * 32, ty + g * (i + 1) - 1, 171 + idx * 32, ty + g * (i + 1) + 1)
        draw.draw(f)
      end
    end
    agcmy /= andc

    andc.times do |i|
      ty = 120 + agcgp * (3 * i + 1)
      st = agcsx + agcxx * 14
      wg = (820 - st) / andc * 3 / 4
      draw = Magick::Draw.new
      m = st + wg * (i * 2 < andc ? andc - i : i + 1)
      m = 820 + 90 if i == andc - 1 - i
      draw.line(st, ty + agcgp, m, ty + agcgp)
      draw.draw(f)
      next if i == andc - 1 - i
      hg = 280 / (andc + 1)
      nh = agcmy - 140 + hg * (i + 1)
      draw = Magick::Draw.new
      draw.line(m, ty + agcgp, m, nh)
      draw.draw(f)
      draw = Magick::Draw.new
      draw.line(m, nh, 820 + 90, nh)
      draw.draw(f)
    end

    draw = Magick::Draw.new
    draw.fill('black')
    draw.polygon(*shift[scale[ogc, 10, 20], 820, agcmy - 140])
    draw.draw(f)

    draw = Magick::Draw.new
    draw.stroke('black')
    draw.stroke_width(3)
    draw.line(820 + 140, agcmy, 1150, agcmy)
    draw.draw(f)

    draw = Magick::Draw.new
    draw.annotate(f, 0, 0, 1180, agcmy + 10, 'out') do
      self.pointsize = 36
    end

    f.write("#{@name}_diagram.png")
  end

  def generate_verilog
    _ = true if @solution[0] == :neg
    ands = (0...@solution.size - 1).map { |i| "and#{i}" } .join ', '
    noth = {}.tap do |h|
      @solution[1..-1].each do |a|
        a.each do |s|
          unless s.match(/!/).nil?
            next if h.include?(s)
            c = h.size
            h[s] = c
          end
        end
      end
    end
    nots = (0...noth.size).map { |i| "not#{i}" } .join ', '

    File.open("#{@name}.v", "w") do |f| 
      s = <<-EOS
module #{@name}_G(in, out);
  parameter n = #{@n};

  input [n - 1 : 0]in;
  output out;
#{"\n  wire or0;" if _}#{"\n  wire #{nots};" unless nots.empty?}
#{"  wire #{ands};\n"}
#{noth.to_a.sort_by(&:last).map { |s, c| "  not not_#{c}(not#{c}, in[#{s.match(/\d+/)[0]}]);"} .join(?\n) }#{?\n unless noth.empty? }
#{@solution[1..-1].zip(0...@solution.size - 1).map { |a, i| "  and and_#{i}(and#{i}, " + "#{a.map { |s| s.match(/!/).nil? ? "in[#{s.match(/\d+/)[0]}]" : "not#{noth[s]}"} .join(', ')});" } .join(?\n) }
#{_ ? "\n  or or_0(or0, #{ands});\n\n  not not_f(out, or0);" : "\n  or or_0(out, #{ands});" if ands.size > 1}
endmodule

module #{@name}_D(in, out);
  parameter n = #{@n};

  input [n - 1 : 0]in;
  output out;

  assign out = #{'!(' if _}#{@solution[1..-1].map { |a| a.map { |s| s.gsub(/\d+/, "in[\\0]") } .join(' & ') } .join(" |\n" + ' ' * (15 + (_ ? 2 : 0))) }#{?) if _}#{?;}
endmodule

module #{@name}_B(in, out);
  parameter n = #{@n};

  input [n - 1 : 0]in;
  output out;
  reg out;

  always@(*)begin
    case(in)
      #{@t.join ', '} : begin
        out = 1'b1;
      end
      default : begin
        out = 1'b0;
      end
    endcase
  end
endmodule
      EOS
      f.puts s
    end
    
    File.open("#{@name}_tb.v", "w") do |f|
      s = <<-EOS
module #{@name}_tb;
  parameter delay = 5;
  
  wire out_G, out_D, out_B;
  reg [#{@n - 1} : 0]in;
  integer i;

  initial begin
    in = 0;
    for (i = 0; i < #{1 << @n}; i = i + 1) begin
      #delay
      $display("time = %4d, in = %b, out_G = %b, out_D = %b, out_B = %b", $time, in, out_G, out_D, out_B);
      if (!(out_G == out_D && out_D == out_B) || 
          ((#{@t.map { |x| "in == #{x}" } .join ' || '}) && !out_G) ||
          (!(#{@t.map { |x| "in == #{x}" } .join ' || '}) && out_G))
      begin
        $display("You got wrong answer!!");
        $finish;
      end
      in = in + 1;
    end
    $display("Congratulations!!");
    $finish;
  end

#{%w(G D B).map { |c| "  #{@name}_#{c} hv#{c.downcase}(.in(in), .out(out_#{c}));" } .join ?\n}
endmodule
      EOS
      f.puts s
    end
  end
end

solver = Lab1.new
solver.render_kmap
solver.render_circuit
solver.generate_verilog
