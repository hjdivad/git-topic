# encoding: utf-8

module GitTopic; end
module GitTopic::Comment

  module ClassMethods

    def diff_to_file_specific_notes( diff, opts={} )
      raise "
        Must specify :author to attribute diffs to.
      " unless opts.has_key? :author

      initial_buffer        = StringIO.new
      comment_buffer        = ''
      flush_comment_buffer  = lambda do
        next if comment_buffer.empty?
        formatted_comment    = comment_buffer.wrap(
                                80,
                                4,
                                attrib( opts[:author], 4 ))
        initial_buffer.puts formatted_comment
        comment_buffer = ''
      end

      diff.each_line do |line|
        flush_comment_buffer.call unless line =~ %r{^\+[^+]}
        case line
        when %r{^diff --git a/(.*) }
          path = $1
          initial_buffer.puts "\n\n" unless initial_buffer.size == 0
          initial_buffer.puts "./#{path}"
        when %r{^@@ -(\d+),}
          line = $1.to_i + 1
          initial_buffer.puts ""
          initial_buffer.puts "  Line #{line}"
        when %r{^\+[^+]}
          raise "
            Diff includes non-comment additions.  Each added line must be
            prefixed with any amount of whitespace and then a ‘#’ character.
          ".oneline unless line =~ %r{^\+\s*#(.*)}
         
          comment_part = "#{$1}\n"
          comment_buffer << comment_part
        when %r{^old mode}
          raise "Diff includes mode changes."
        when %r{^\- }
          raise "Diff includes deletions."
        end
      end
      flush_comment_buffer.call
      initial_buffer.string
    end

    def collect_comments( edit_file )
      author          = git_author_name_short
      diff            = capture_git(
                          "diff --diff-filter=M -U0 --no-color --no-renames -B",
                          :must_succeed => true )

      # file specific notes computed from diff
      fs_notes        = diff_to_file_specific_notes( diff, :author => author )
      edit_file       = "#{git_dir}/COMMENT_EDITMSG"

      # solicit the user (via GIT_EDITOR) for any general notes beyond the file
      # specific ones
      File.open( edit_file, 'w' ) do |f|
        f.puts %Q{
          # Edit this file to include whatever general comments you would like.
          # The file specific comments, shown below, will be appended to
          # anything you put here.  Your comments will automatically be
          # attributed.
          #
          # Any lines beginning with a ‘#’ character will be ignored.
          #
          #
          # Ceterum censeo, Carthaginem esse delendam.
          #
          #
        }.unindent
        f.puts( fs_notes.lines.map do |line|
            "# #{line}"
          end.join )
      end
      invoke_git_editor( edit_file )

      # combine the general and file_specific notes
      general_notes = File.readlines( edit_file ).reject do |line|
        line =~ %r{^\s*#}
      end.join( "" ).strip

      unless general_notes.empty?
        general_notes.wrap!( 80, 4, attrib( author ))
      end

      notes = [general_notes, fs_notes].reject{ |n| n.empty? }.join( "\n\n" )

      notes
    end

    def notes_from_initial_comments( mode="add" )
      raise %Q{
        Illegal mode [#{mode}].  Specify either “add” or “edit”
      } unless ["add", "edit"].include? mode

      edit_file       = "#{git_dir}/COMMENT_EDITMSG"
      notes           = collect_comments( edit_file )

      # Write the complete set of comments to a git note at the appropriate ref
      File.open( edit_file, 'w' ){ |f| f.write( notes )}
      git "notes --ref #{notes_ref} #{mode} -F #{edit_file}",
          :must_succeed => true

      # If all has gone well so far, clear the diff
      git "reset --hard"
    end


    def notes_to_hash( notes )
      result        = {}
      current_hash  = result
      key           = :general
      pos           = -1

      update_key    = lambda do
        current_hash[ key ] = pos + 1 unless key.nil?
      end

      notes.lines.each_with_index do |line, line_no|
        case line
        when %r{^(./.*)}
          # new file
          update_key.call
          path            = $1
          result[ path ]  = {}
          current_hash    = result[ path ]
          key             = nil
        when %r{^\s*Line (\d+)\s*$}
          # new line in existing file
          update_key.call
          comment_line_no = $1.to_i
          key             = comment_line_no
        end
        pos = line_no unless line =~ %r{^\s*$}
      end
      update_key.call

      result
    end

    def append_reply( notes, content, opts={} )
      raise "
        Must specify :author to attribute diffs to.
      " unless opts.has_key? :author

      notes_hash      = notes_to_hash( notes )
      result          = notes.split( "\n" )
      replies         = {}
      reply_at_line   = notes_hash[ :general ]
      context_file    = nil
      context_line    = nil
      reply           = nil

      add_reply       = lambda do
        break if reply.nil?

        unless context_file.nil?
          raise "
            Unexpected reply to file [#{context_file}]
          ".oneline unless notes_hash.has_key? context_file

          raise "
            Unexpected reply to file [#{context_file}] without a line context.
          ".oneline if context_line.nil?

          raise "
            Unexpected reply to context line [#{context_line}] of file
            [#{context_file}]
          ".oneline unless notes_hash[ context_file ].has_key? context_line
        end

        attrib_indent = 
          reply_at_line == notes_hash[ :general ] ? 0 : 4

        replies[ reply_at_line ] = 
          reply.strip.wrap( 80, 4, attrib( opts[:author], attrib_indent ))

        reply = nil
      end

      content.each_line do |line|
        case line
        when %r{^# (./.*)$}
          # Context switched to new file
          add_reply.call
          context_file  = $1
          context_line  = nil
          reply_at_line = nil
        when %r{^#\s*Line (\d+).*$}
          add_reply.call
          context_line  = $1.to_i
          file_hash     = notes_hash[ context_file ]
          reply_at_line = file_hash && file_hash[ context_line ]
        when %r{^\s*#}
          # non-signposting comment, ignore it
        else
          (reply ||= '' ) << line
        end
      end
      add_reply.call

      replies.keys.sort.reverse.each do |reply_at_line|
        reply_content       = replies[ reply_at_line ]
        i                   = reply_at_line
        result[ i..i ]      = reply_content, result[ i ]
      end

      result.join( "\n" )
    end

    def notes_from_reply_to_comments
      raise "There is nothing to reply to." unless existing_comments?

      notes           = existing_comments
      edit_file       = "#{git_dir}/COMMENT_EDITMSG"
      File.open( edit_file, 'w' ) do |f|
        f.puts %Q{
          # Edit this file to include your replies.  Place your replies below
          # either the general comments, or below a comment on a specific line
          # in a specific file.  Do not remove any of the existing lines.
          #
          # Any lines beginning with a ‘#’ character will be ignored.
          #
          #
          # In the beginning the Universe was created. This has made a lot of
          # people very angry and been widely regarded as a bad move.  
          #                                                     Douglas Adams
          #
          #
        }.unindent
        f.puts( notes.lines.map do |line|
            "# #{line}"
          end.join )
      end
      invoke_git_editor( edit_file )
      content           = File.read( edit_file ) 

      notes_with_reply  = append_reply(
                            notes,
                            content,
                            :author => git_author_name_short )

      File.open( edit_file, 'w' ){ |f| f.write( notes_with_reply )}


      if notes_with_reply != notes
        git "notes --ref #{notes_ref} edit -F #{edit_file}",
            :must_succeed => true
      else
        # No comments to add.
        return false
      end
    end

    def attrib( author, indent=0, max_w=16 )
      w = max_w - indent
      attrib = 
        if author.size < w
          "#{author}:"
        else
          fname = author.split.first
          "#{fname[0...w-1]}:"
        end
      sprintf "%s%-#{w}.#{w}s", (' ' * indent), attrib
    end

  end

  def self.included( base )
    base.extend ClassMethods
  end
end
