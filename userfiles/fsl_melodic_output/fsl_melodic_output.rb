#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

class FslMelodicOutput < FileCollection
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  fsl_logo_name  = "fsl-logo-big.jpg"
  fsl_img_url    = "http://fsl.fmrib.ox.ac.uk/fsl/wiki_static/fsl/img"
  
  has_viewer :name => "Melodic Viewer",  :partial => :melodic_viewer

  ##################################################################################################
  # This method returns the content of an HTML file modified so that it can be
  # displayed in the content section of the userfile page.  It
  # basically removes some HTML tags (html, body, object, head, title)
  # and tweaks the URLs found in <a> and <img> tags.  It is quite
  # specific to the HTML pages generated by FSL melodic. A more
  # generic implementation would require a complete parsing of the
  # HTML code.  It is recursively called for each iframe contained in
  # the page.
  # Parameters:
  #  * file_path: the path of the HTML file whose content will be read, modified and returned. 
  #  * dir_name: the directory name of the HTML file in the melodic file collection.
  ##################################################################################################
  
  def modified_file_content file_path,dir_name
    return nil unless File.exists?(file_path)
    lines = Array.new
    # The file is processed line by line to speed up substitutions.
    File.open(file_path).each do |line|
      # Tweaks hrefs.
      new_line = tweak_hrefs_in_line(line,dir_name)
      # Tweaks imgs.
      new_line = tweak_imgs_in_line(new_line,"#{self.name}/#{dir_name}")
      # Remove specific tags.
      new_line = new_line.gsub(/<object.*object>/i,"")
      new_line = new_line.gsub(/<link.*stylesheet.*>/i,"")
      new_line = new_line.gsub(/<html>/i,"")
      new_line = new_line.gsub(/<\/html>/i,"")
      new_line = new_line.gsub(/<body>/i,"")
      new_line = new_line.gsub(/<\/body>/i,"")
      new_line = new_line.gsub(/<head>/i,"")
      new_line = new_line.gsub(/<\/head>/i,"")
      new_line = new_line.gsub(/<title>.*<\/title>/i,"")
      # Handles iframes.
      keep_line = true
      new_line.scan(/<IFRAME.*src=(.*) /i) do |x,y|
	frame_path = File.dirname(file_path)+"/"+x
   	lines << modified_file_content(frame_path,dir_name)
	keep_line = false					  
      end
      lines << new_line if keep_line
    end
    return lines
  end

  ##################
  # Helper methods #
  ##################
  
  private

  # Appends a string to the href attribute of a link, making sure that the string is appended after 'key'.
  # Examples:
  # * href attribute is not quoted (not sure it's valid, but it happens in FSL pages)
  #    append_string_to_link("<a href=someplace?file_name=foo&param=bar   > hello","file_name","AAA")
  #         => "<a href=someplace?file_name=foo&param=barAAA   > hello"
  # * href attribute is quoted, and it has trailing spaces.
  #      append_string_to_link "<a href=\"someplace?file_name=foo&param=bar \"   > hello","file_name","AAA"
  #         => "<a href=\"someplace?file_name=foo&param=barAAA \"   > hello"
  # * another attribute is after href
  #    append_string_to_link "<a href=\"someplace?file_name=foo&param=bar alt=\"coin\"   > hello","file_name","AAA"
  #        => "<a href=\"someplace?file_name=foo&param=barAAA alt=\"coin\"   > hello"
  # * another tag is before href, that contains the string "href"
  #    append_string_to_link "<a alt=\"href link\" href=\"someplace?file_name=foo&param=bar \"   > hello","file_name","AAA"
  #        => "<a alt=\"href link\" href=\"someplace?file_name=foo&param=barAAA \"   > hello"
  def append_string_to_link link,key,string
    new_link = link
    return link if (! key.present?) || new_link.index(key).nil?
    index_space = new_link.index(' ',new_link.index(key))
    index_quote = new_link.index('"',new_link.index(key))
    index_greater = new_link.index('>',new_link.index(key))
    index_min = [index_space,index_quote,index_greater].min rescue nil
    return link if index_min.nil?
    new_link.insert(index_min,string)
    return new_link
  end

  # Modifies the href attribute of a link.
  def tweak_href_of_link link,dir_name
    new_link = link

    if link.downcase.include? "http"
      # do not tweak links that are external URLs
      return link
    end

    # Treat separately the following cases:
    # href="..." (with quote)
    # href=... (without quote)
    if new_link.downcase.gsub(" ","").include? "href=\""
      new_link = new_link.gsub(/HREF="/i,'href="./userfile.id?file_name=@dirname')
    else
      new_link = new_link.gsub(/HREF=/i,'href=./userfile.id?file_name=@dirname')
    end
    new_link.gsub!("userfile.id","#{self.id}")
    new_link.gsub!("@dirname","#{dir_name}")
    new_link.gsub!('/"',"/")

    # Append #file_content to the URL
    new_link = append_string_to_link(new_link,"file_name","#file_content")

    new_link.gsub!(/file_name=(.*?)gica\//,"file_name=")
    
    return new_link
  end

  # Modifies all the hrefs in a line. 
  def tweak_hrefs_in_line line,dir_name
    new_line = line
    line.split(/<a/i).each do |link|
      next if link == ""
      new_link = tweak_href_of_link(link,dir_name)
      new_line = new_line.gsub(link,new_link)
    end
    return new_line
  end

  # Modifies the src attribute of an img. 
  def tweak_img link,dir_name
    new_link = link
    if link.downcase.include? "http"
      # do not tweak links that are external URLs
      return link
    end
    # Replaces local link to FSL logo
    # (which is not in the file collection)
    # with external link.
    if link.include?(fsl_logo_name)
      return "<img src=\"#{fsl_img_url}/#{fsl_logo_name}\" width=165/>"
    end
    if new_link.downcase.gsub(" ","").include?("src=\"")
      new_link = new_link.gsub(/src="/i,'src="userfile.id/content?arguments=@dirname')
    else
      new_link = new_link.gsub(/src=/i,'src=userfile.id/content?arguments=@dirname')
    end
    new_link.gsub!("userfile.id","#{self.id}")
    new_link.gsub!("@dirname","#{dir_name}")
    new_link.gsub!('/"',"/")            

    new_link = append_string_to_link(new_link,"arguments","&content_loader=collection_file&content_viewer=off&viewer=image_file&viewer_userfile_class=ImageFile")
    new_link.gsub!(/gica(.*?)gica/,"gica")
    
    return new_link
  end
  
  # Modifies all the imgs found in a line.
  def tweak_imgs_in_line line,dir_name
    new_line = line
    line.scan(/<img.*>/i) do |img,y|
      new_img = tweak_img(img,dir_name)
      new_line = new_line.gsub(img,new_img)
    end
    return new_line
  end
  
end
