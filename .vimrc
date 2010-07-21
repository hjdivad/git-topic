let $RUBYPATH = 'lib' 

function! s:run_example()
    if &ft != "ruby"
        " Not ruby, do nothing.
        return
    endif

    " look for it ", with no word character just before ‘it’
    let line    = search( '\w\@<!it "', "bnW" )
    let cmd     = "rspec --no-color " . expand( "%" ) . " -l " . line

    if line > 0
        execute "!" . cmd
    else
        echo "No rspec example found at or before cursor position."
    endif
endfun
nmap <leader>t :call <SID>run_example()<CR>


