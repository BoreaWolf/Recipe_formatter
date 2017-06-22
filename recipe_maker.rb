#!/usr/bin/env ruby

# Author: Riccardo Orizio
# Date: 13 November 2015
# A program that reads a recipe from a website and creates a pdf about it

require "prawn"
require "open-uri"
require "nokogiri"

# Paths and Constants
IMAGES_PATH = "./images/"
FONTS_PATH = "./fonts/"
FONTS_EXTENSION = ".ttf"
RECIPES_PATH = "./recipes/"

ERROR_WEBSITE_NOT_AVAILABLE = "This site is not available yet, sorry! へ‿(ツ)‿ㄏ"

DEFAULT_MARGIN = 36
FONT_SIZE_TITLES = 100
FONT_SIZE_INGREDIENTS = 50
FONT_SIZE_PEOPLE = 75 
FONT_SIZE_TEXT = 50
PADDING_TITLES = 40 
PADDING_LATERAL = 25
PADDING_TOP_INGREDIENTS = 75 
PADDING_TOP_PEOPLE = 25

TITLE_INGREDIENTS = "Ingredienti"
TITLE_PROCEDURE = "Preparazione"
TITLE_ADVICE = "Consiglietto di Sonietta la birichina :P"

LIST_INGREDIENT = "- "
EMPTY_ADVICE = "ᕕ[ ᓀ ڡ ᓂ ]ㄏ─∈"

PAGE_DIM = [ 2100, 2970 ]
REAL_PAGE_DIM = [ PAGE_DIM[ 0 ] - DEFAULT_MARGIN * 2, PAGE_DIM[ 1 ] - DEFAULT_MARGIN * 2 ]
RATE_IMAGE_HEIGHT = 0.33
RATE_INGR_WIDTH = 0.33
RATE_INGR_HEIGHT = 0.50
RATE_PROC_WIDTH = 1 - RATE_INGR_WIDTH
RATE_PROC_HEIGHT = RATE_INGR_HEIGHT
# RATE_ADV_HEIGHT = 1 - RATE_IMAGE_HEIGHT - RATE_INGR_HEIGHT
RATE_ADV_HEIGHT = 0.10

Recipe = Struct.new( :name, :photo, :presentation, :people, :ingredients, :procedure, :advice )
recipe = Recipe.new()

link = ARGV[ 0 ]
content = Nokogiri::HTML( open( link, &:read ) )

# Reading data from the HTML page

if link.include? "ricette.giallozafferano" then
	# Giallo Zafferano Ricette
	content = content.css( "article#content" )
	recipe[:name] = content.css( "h1" )[ 0 ].text
	recipe[:photo] = content.css( "img" ).select{ |img| img["alt"] == recipe[:name] }[ 0 ][ "src" ]

	content = content.css( "div.right-push" )
	recipe[:people] = content.css( "li.yield strong" ).text
	recipe[:ingredients] = content.css( "dl dd.ingredient" )
	ingrs = Array.new
	recipe[:ingredients].each do |ingr|
		ingrs.push( LIST_INGREDIENT + ingr.text.gsub( /(\n|\t|,)+/, " " ).gsub( /\s+/, " " ).strip )
	end
	recipe[:ingredients] = ingrs
	
	# Looking for some stupid advertisements
	adv = content.css( "div.btesto p" ).text
	recipe[:procedure] = content.css( "p" )
	recipe[:procedure] = recipe[:procedure].select{ |p| p["class"].class == NilClass and p["id"].class == NilClass }
	recipe[:presentation] = recipe[:procedure][ 0 ].text
	recipe[:procedure].shift
	recipe[:procedure].map!{ |elem| elem.text }
	recipe[:procedure].map!{ |elem| elem.sub( adv, "" ) }
	recipe[:procedure].map!{ |elem| elem unless elem.start_with?( "\n\t" ) }.compact!
	# Removing the image references from the text
	recipe[:procedure].map!{ |elem| elem.gsub( /(\s|\S)\(\d+(-\d+)?\)/, "" ) }

	recipe[:advice] = content.css( "div.consiglio p" ).text
elsif link.include? "blog.giallozafferano" then
	# Giallo Zafferano Blog
	# This site sucks a$$
	content = content.css( "div#content" )
	recipe[:name] = content.css( "h1.entry-title" ).text
	recipe[:photo] = content.css( "img.alignleft" )[ 0 ][ "src" ]
	recipe[:presentation] = "" 
	recipe[:people] = "THAT many, not more"
	recipe[:ingredients] = [ "A bit of this", "and", "A bit of that" ]
	recipe[:procedure] = [ "Look here or change recipe :P", link ]
	recipe[:advice] = "Go and look for the same recipe in another site :D"
elsif link.include? "cookaround" then
	# Cookaround
	content = content.css( "div.left.hrecipe" )
	recipe[:name] = content.css( "h1.fn" ).text
	recipe[:photo] = content.css( "span.loopimg.noicon img" )[ 0 ][ "src" ]
	recipe[:people] = content.css( "li.yield strong" ).text
	recipe[:presentation] = content.css( "p" )
	recipe[:presentation] = recipe[:presentation].select{ |p| p["class"].class == NilClass }.to_a.map!{ |p| p.text }
	recipe[:ingredients] = content.css( "div.r-datas ul li.ingredient" )
	ingrs = Array.new
	recipe[:ingredients].each do |ingr|
		ingrs.push( LIST_INGREDIENT + ingr.text.gsub( /(\n|\t|,)+/, " " ).gsub( /\s+/, " " ).strip )
	end
	recipe[:ingredients] = ingrs
	recipe[:procedure] = content.css( "p.prep.step" ).to_a.map!{ |step| step.text }
	recipe[:advice] = ""
elsif link.include? "alice" then
	# Alice.tv
	content = content.css( "div#left-area" )
	recipe[:name] = content.css( "h1.ricette" ).text
	recipe[:photo] = content.css( "img" ).select{ |img| img["alt"] == recipe[:name] }[ 0 ][ "src" ]
	recipe[:presentation] = "" 
	recipe[:people] = ""
	recipe[:ingredients] = content.css( "div.ingredienti" ).to_a.map!{ |ingr| LIST_INGREDIENT + ingr.css( "span" ).text }
	recipe[:ingredients].map!{ |ingr| ingr.gsub( /(\n|\t|\s)+:(\n|\t|\s)+/, ": " ).strip }
	recipe[:procedure] = content.css( "div.passaggi_text" ).to_a.map!{ |step| step.text }
	recipe[:advice] = ""
elsif link.include? "misya" then
	content = content.css( "div.row" )
	recipe[:name] = content.css( "h1" ).text
	recipe[:photo] = content.css( "img" ).select{ |img| img["alt"] == recipe[:name] }[ 0 ][ "src" ]
	recipe[:presentation] = "" 
	recipe[:people] = content.css( "div.tit-ingr" ).text.gsub( /Ingredienti per |:/, "" ).capitalize
	recipe[:ingredients] = content.css( "ul.list-ingr li" ).map{ |ingr| ingr.text.strip.capitalize }
	recipe[:procedure] = content.css( "div" ).select{ |div| div["name"] == "istruzioni" }.first
	recipe[:procedure] = recipe[:procedure].css( "p" ).select{ |p| p.text != "" and !p.text.include? "video" }.map{ |p| p.text.strip } 
	recipe[:advice] = ""
else
	abort( ERROR_WEBSITE_NOT_AVAILABLE )
end

# Dropping multi space
recipe[:name] = recipe[:name].gsub( /\s+/, " " )
# Saving the image locally
img_filename = IMAGES_PATH + 
			   recipe[:name].gsub( /[.?*+^$\\\/()\[\]{}|\-_'"\s]/, "_" ) +
			   File.extname( recipe[:photo] )
open( img_filename, "wb" ) do |img|
	img << open( recipe[:photo] ).read
end
recipe[:photo] = img_filename

# Reading important stuff from the page

# PDF filename, same as the name recipe
# I'll work on the photo cause I only have to change its extension to pdf
pdf_filename = recipe[:photo].sub( IMAGES_PATH, RECIPES_PATH ).sub( File.extname( recipe[:photo] ), ".pdf" )
Prawn::Document.generate( pdf_filename,
						  :page_size => PAGE_DIM ) do |pdf_file|

	# Fonts
	font_files = Dir[ "#{FONTS_PATH}*#{FONTS_EXTENSION}" ]
	fonts = Array.new
	font_files.each do |font|
		fonts.push( [ font, font.rpartition( "/" )[2].partition( "." )[0] ] )
	end
	fonts.each do |font|
		pdf_file.font_families.update(
			font[ 1 ] => {
				:normal =>		{ :file => font[ 0 ], :font => font[ 1 ]  },
				:italic => 		{ :file => font[ 0 ], :font => font[ 1 ] + "-Italic" },
				:bold =>		{ :file => font[ 0 ], :font => font[ 1 ] + "-Bold" },
				:bold_italic =>	{ :file => font[ 0 ], :font => font[ 1 ] + "-BoldItalic" }
			} )
	end

	# Title
	pdf_file.font( "FFF_Tusj", :size => FONT_SIZE_TITLES ) do
		pdf_file.text recipe[:name], :align => :center
	end

	# Image
	img_box_size = [ REAL_PAGE_DIM[ 0 ], REAL_PAGE_DIM[ 1 ] * RATE_IMAGE_HEIGHT ]
	pdf_file.bounding_box( [ 0, pdf_file.cursor ], :width => img_box_size[ 0 ], :height => img_box_size[ 1 ] ) do
		pdf_file.image recipe[:photo], :position => :center, :fit => img_box_size
	end

	# Ingredients
	ingr_box_size = [ REAL_PAGE_DIM[ 0 ] * RATE_INGR_WIDTH, REAL_PAGE_DIM[ 1 ] * RATE_INGR_HEIGHT ]
	pdf_file.bounding_box( [ 0, pdf_file.cursor ], :width => ingr_box_size[ 0 ], :height => ingr_box_size[ 1 ] ) do
		pdf_file.font( "Montez_Regular", :size => FONT_SIZE_TITLES ) do
			pdf_file.pad_top( PADDING_TOP_INGREDIENTS + PADDING_TITLES ) { pdf_file.text TITLE_INGREDIENTS, :align => :center }
		end

		pdf_file.font( "Montez_Regular", :size => FONT_SIZE_PEOPLE ) do
			pdf_file.text recipe[:people], :align => :center
		end
		pdf_file.font( "AmaticSC_Regular", :size => FONT_SIZE_INGREDIENTS ) do
			pdf_file.text_box recipe[:ingredients].join( "\n" ),
							  :at => [ PADDING_LATERAL, ingr_box_size[ 1 ] -
										( FONT_SIZE_TITLES + 2 * PADDING_TITLES +
										  FONT_SIZE_PEOPLE + 
										  PADDING_TOP_PEOPLE + PADDING_TOP_INGREDIENTS ) ],
							  :overflow => :shrink_to_fit,
							  :align => :center,
							  :width => ingr_box_size[ 0 ] - 2 * PADDING_LATERAL
		end
	end
	
	# Procedure
	proc_box_size = [ REAL_PAGE_DIM[ 0 ] * RATE_PROC_WIDTH, REAL_PAGE_DIM[ 1 ] * RATE_PROC_HEIGHT ]
	pdf_file.bounding_box( [ ingr_box_size[ 0 ], pdf_file.cursor + ingr_box_size[ 1 ] ], :width => proc_box_size[ 0 ], :height => proc_box_size[ 1 ] ) do
		pdf_file.font( "Montez_Regular", :size => FONT_SIZE_TITLES ) do
			pdf_file.pad( PADDING_TITLES ) { pdf_file.text TITLE_PROCEDURE, :align => :center }
		end
		pdf_file.font( "Walkway_Oblique", :size => FONT_SIZE_TEXT ) do
			pdf_file.text_box recipe[:procedure].join( "\n" ),
							  :at => [ PADDING_LATERAL, proc_box_size[ 1 ] - ( FONT_SIZE_TITLES + 2 * PADDING_TITLES ) ],
							  :overflow => :shrink_to_fit,
							  :align => :justify,
							  :width => proc_box_size[ 0 ] - 2 * PADDING_LATERAL
		end
	end

	# Advice
	if recipe[:advice] != "" then
		adv_box_size = [ REAL_PAGE_DIM[ 0 ], REAL_PAGE_DIM[ 1 ] * RATE_ADV_HEIGHT ]
		pdf_file.bounding_box( [ 0, pdf_file.cursor ], :width => adv_box_size[ 0 ], :height => adv_box_size[ 1 ] ) do
			pdf_file.font( "Montez_Regular", :size => FONT_SIZE_TITLES ) do
				pdf_file.pad( PADDING_TITLES ) { pdf_file.text TITLE_ADVICE, :align => :center }
			end

			pdf_file.font( "Walkway_Oblique", :size => FONT_SIZE_TEXT ) do
				pdf_file.text_box recipe[:advice],
					:at => [ PADDING_LATERAL, adv_box_size[ 1 ] - ( FONT_SIZE_TITLES + 2 * PADDING_TITLES ) ],
					:overflow => :shrink_to_fit,
					:align => :justify,
					:width => adv_box_size[ 0 ] - 2 * PADDING_LATERAL
			end
		end
	end
end

puts "Created '#{pdf_filename}'! ᕕ[ ᓀ ڡ ᓂ ]ㄏ─∈"

