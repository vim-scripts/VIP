" VIP : VHDL Interface Plugin
" File:        vip.vim
" Version:     1.2.0
" Last Change: dec. 12 2010
" Author:      Jean-Paul Ricaud
" License:     LGPLv3
" Description: Copy entity (or component) and paste as component (or entity)
"              or instance of component

if exists("g:loaded_VIP")
  finish
endif
let g:loaded_VIP = 1

" Global variables
if !exists("g:instPrefix_VIP")
  let g:instPrefix_VIP = ""             " the prefix added at the beginning of an instance name
endif
if !exists("g:instSuffix_VIP")
  let g:instSuffix_VIP = "_"            " the suffix added at the end of an instance name
endif
if !exists("g:sigPrefix_VIP")
  let g:sigPrefix_VIP = "s_"            " the prefix added to signals names
endif
if !exists("g:entityWord_VIP")
  let g:entityWord_VIP = "entity"       " the 'entity' word when pasted as entity
endif
if !exists("g:componentWord_VIP")
  let g:componentWord_VIP = "component" " the 'component' word when pasted as component
endif
if !exists("g:autoInc_VIP")
  let g:autoInc_VIP = 1                 " allows auto-incrementation of instance's name
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Simple paste
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:SPaste(yankBlock)
  call append(line("."), a:yankBlock)
  return 1
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Paste a component / entity as an entity / component
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:PasteEC(blockType, blockSubstitute, yankBlock)
  let copyType  = a:blockType " to avoid alteration of the copied block
  let copyBlock = copy(a:yankBlock) " to avoid alteration of the original block
  let newBlock = map(copyBlock, 'substitute(v:val, copyType, a:blockSubstitute, "g")')
  call append(line("."), newBlock)
  return 1
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Paste an instance of component as an instance of component
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:PasteII(autoInc, instanceNumb, instSuffix, yankBlock)
  let copyBlock = copy(a:yankBlock) " to avoid alteration of the original block
  let currentList = split(copyBlock[0])
  let pos = 0
  let posN = 0

  try
    " Let's check if the instance has already a suffix
    " Get the position of the last suffix in the name if it exisits
    while posN != -1
      let posNumb = posN
      let pos += 1
      let posN = match(currentList[0], a:instSuffix, pos)
    endwhile

    if posNumb > 0
      " Instance has already a suffix
      if a:autoInc == 1
        let posNumb += strlen(a:instSuffix)
        let instNumb = str2nr(strpart(currentList[0], posNumb)) + 1
        let instNumb += a:instanceNumb
        let newName = strpart(currentList[0], 0, posNumb)
        let currentList[0] = newName.instNumb
      endif
    else
      " Instance hasn't a suffix, adding a suffix
      let currentList[0] = currentList[0].a:instSuffix
      if a:autoInc == 1
        let currentList[0] = currentList[0].a:instanceNumb
      endif
    endif
  catch
    echohl WarningMsg | echo  "VIP error : can't paste, please check the formating of copied block, see doc." | echohl None
    return 0
  endtry

  let copyBlock[0] = join(currentList)
  " Let's add the original indentation of the instance
  let indentPos = match(a:yankBlock[0], "[a-zA-Z]") " first char of an identifiers must be a letter
  let indentVal = strpart(a:yankBlock[0], 0, indentPos)
  let copyBlock[0] = indentVal.copyBlock[0]
  let result = s:SPaste(copyBlock)
  return 1
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Clean up the block before paste as instance of component
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:CleanECI(yankBlock)
  let newBlock = []
  let nbOfLines = len(a:yankBlock) - 1

  try
      let save_iskeyword = &iskeyword
      set iskeyword -=(

    for i in range(0, nbOfLines)
      let currentLine = a:yankBlock[i]
      let indentPos = match(currentLine, "[a-zA-Z]") " first char of an identifiers must be a letter
      let indentVal = strpart(currentLine, 0, indentPos)
      let skip = 0

      " put signal after generic's brace to a new line
      let portPos = match(currentLine, '\c\<generic\>')
      if portPos != -1
        let beforePort = strpart(currentLine, 0, portPos)
        let newBlock += [beforePort."generic ("]
        let bracePos = match(currentLine, '(') + 1
        if bracePos != 0
          let afterBrace = strpart(currentLine, bracePos)
          let afterBrc = substitute(afterBrace, "\[ \t]", "", "g")
        else
          let afterBrace = ""
          let afterBrc = ""
        endif
        if afterBrc != ""
          let currentLine = indentVal.s:indChar.afterBrace
        else
          let skip = 1
        endif
      endif

      " put signal after port's brace to a new line
      let portPos = match(currentLine, '\c\<port\>')
      if portPos != -1
        let beforePort = strpart(currentLine, 0, portPos)
        let newBlock += [beforePort."port ("]
        let bracePos = match(currentLine, '(') + 1
        if bracePos != 0
          let afterBrace = strpart(currentLine, bracePos)
          let afterBrc = substitute(afterBrace, "\[ \t]", "", "g")
        else
          let afterBrace = ""
          let afterBrc = ""
        endif
        if afterBrc != ""
          let currentLine = indentVal.s:indChar.afterBrace
        else
          let skip = 1
        endif
      endif

      " Put each signal seperated by , to a new line
      if skip == 0
        let subLines = split(currentLine, ',')
        let indentPos = match(currentLine, "[a-zA-Z]") " first char of an identifiers must be a letter
        let indentVal = strpart(currentLine, 0, indentPos)
        let j = 0
        for subWords in subLines
          let subWds = substitute(subWords, "\[ \t]", "", "g") " remove space & tab at begenning of line
          if j != 0
            let subWords = indentVal.subWds
          else
            let subWords = subWords
          endif
          if subWds != "("
            let newBlock += [subWords]
          endif

          let j += 1
        endfor
      endif

    endfor

    let &iskeyword = save_iskeyword
  catch
    echohl WarningMsg | echo  "VIP error : can't copy, please check the formating of copied block, see doc." | echohl None
    return []
  endtry

  return newBlock
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Paste a component / entity as an instance of component
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:PasteECI(instanceNumb, instPrefix, instSuffix, sigPrefix, yankBlock)
  let instanceBlock = []
  let braceCnt = 0
  let inPort = 0
  let inGeneric = 0
  let i = 0
  let j = -1
  let nbOfLines = len(a:yankBlock) - 2

  " Head and tail of the instance
  let instanceName = split(a:yankBlock[0])
  let indentPos = match(a:yankBlock[0], "[a-zA-Z]") " first char of an identifiers must be a letter
  let indentVal = strpart(a:yankBlock[0], 0, indentPos)
  let instanceBlock += [indentVal.a:instPrefix.instanceName[1].a:instSuffix.a:instanceNumb." : ".instanceName[1]]

  try
    " Get signals inside entity / component
    for i in range(0, nbOfLines)
      let currentList = split(a:yankBlock[i])
      let currentLine = a:yankBlock[i]
      let signalBefore = substitute(currentLine, "\:.*$", "", "g") " remove everything after :
      let signalName = substitute(signalBefore, "\[ \t]", "", "g") " remove space & tab at begenning of line
      let currentLine = substitute(currentLine, "\;", "", "g") " remove the ;

      let skipLine = 0
      let j += 1

      if match(signalName, "--") != -1
        let skipLine = 1
        let instanceBlock += [currentLine] " add comment
      endif

      if signalName == "("
        let skipLine = 1 " skip this line
        let j -= 1
      endif

      let k = 0
      for currentWord in currentList

        if (currentWord ==? "generic")
          let inGeneric = 1 " inside generic body
          let skipLine = 1 " skip this line
          if (signalName ==? "generic(")
            let indentPos = match(a:yankBlock[i], "[a-zA-Z]") " first char of an identifiers must be a letter
            let indentVal = strpart(a:yankBlock[i], 0, indentPos)
            let instanceBlock += [indentVal."generic map ("]
          else
            let instanceBlock[j] = instanceBlock[j]." generic map ("
          endif
        endif

        if (currentWord ==? "port")
          let inPort = 1 " inside port body
          let skipLine = 1 " skip this line
          if (signalName ==? "port(")
            let indentPos = match(a:yankBlock[i], "[a-zA-Z]") " first char of an identifiers must be a letter
            let indentVal = strpart(a:yankBlock[i], 0, indentPos)
            let instanceBlock += [indentVal."port map ("]
          else
            let instanceBlock[j] = instanceBlock[j]." port map ("
          endif
        endif

        if (match(currentWord, "(") != -1)
          let braceCnt += 1
        endif

        if (braceCnt > 0) && (skipLine == 0) && (k == 0)
          if inGeneric == 1
            let instanceBlock += [signalBefore." => ,"]
          endif
          if inPort == 1
            let instanceBlock += [signalBefore." => ".a:sigPrefix.signalName.","]
          endif
        endif

        if (match(currentWord, ")")) != -1
          let braceCnt -= 1
          if match(currentWord, "))") != -1 " in case of a (m downto n));
            let braceCnt -= 1 " the first ) has been counted above, the second is counted here
          endif
          if braceCnt == 0
            if signalName == ");" " have we a closing brace at a new line ?
              let instanceBlock[j-1] = substitute(instanceBlock[j-1], "\,", "", "g") " remove the , of last signal
              let instanceBlock[j] = currentLine
            else
              let instanceBlock[j] = substitute(instanceBlock[j], "\,", "", "g") " remove the , of last signal
              let instanceBlock[j] = instanceBlock[j]." )"
            endif

            if inGeneric == 1
              let inGeneric = 0
            endif
            if inPort == 1
              let inPort = 0
              let instanceBlock[j] = instanceBlock[j].";"
            endif

          endif
        endif
        let k += 1
      endfor

    endfor
  catch
    echohl WarningMsg | echo  "VIP error : can't paste, please check the formating of copied block, see doc." | echohl None
    return 0
  endtry

  let instanceBlock += [""] " Add a blank line after the instance
  call append(line("."), instanceBlock)
  return 1
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Copy the block
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:CopyLines(blockType)
  let braceCnt = 0
  let openBlock = 0
  let closeBrace = 0
  let i = 0
  let currentLine = []
  let fLine = line(".")

  try
   let save_iskeyword = &iskeyword
   set iskeyword -=(

    while ((braceCnt != 0) || (closeBrace == 0))
      let currentLine += [getline(fLine + i)]
      let currentList = split(currentLine[i])
      if currentList == []
        echohl WarningMsg | echo  "VIP error : end of block not detected, missing \")\" or \");\" ?" | echohl None
        let &iskeyword = save_iskeyword
        return []
      endif
      for currentWord in currentList

        if (currentWord==? "end")
          echohl WarningMsg | echo  "VIP error : \"end\" detected" | echohl None
          let &iskeyword = save_iskeyword
          return []
        endif
        if (match(currentWord, '\c\<port\>') != -1)
          let openBlock = 1 "Opening of the block detected
        endif
        if ((match(currentWord, "(") != -1) && (openBlock == 1))
          let braceCnt += 1
        endif
        if ((match(currentWord, ")") != -1) && (openBlock == 1))
          let braceCnt -= 1
          let closeBrace = 1
          if match(currentWord, "))") != -1 " in case of a (m downto n));
            let braceCnt -= 1 " the first ) has been counted above, the second is counted here
          endif
        endif

      endfor
      let i += 1
    endwhile

    let &iskeyword = save_iskeyword

    if ((a:blockType ==? "entity") || (a:blockType ==? "component"))
      let currentLine += [getline(fLine + i)] " Get the end entity / end component line
    endif
  catch
    echohl WarningMsg | echo  "VIP error : can't paste, please check the formating of copied block, see doc." | echohl None
    return 0
  endtry

  let currentLine += [""] " let add a blank element to get an empty line after the block
  return currentLine
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Get the line under the cursor, and check if it is an entity,
" a component, an instance
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:CheckType()
  let firstLine = split(getline("."))

  if (firstLine == [])
    " Empty line
    echohl WarningMsg | echo "VIP error : please palce the cursor on entity, component or instance line" | echohl None
    return ""
  endif
  if ((firstLine[0] ==? "port") || (firstLine[0] ==? "generic") || (firstLine[0] ==? ")") || (firstLine[0] ==? ");"))
    " Bad cursor position, cursor should be on "entity", "component"
    " or on the instance name line
    echohl WarningMsg | echo "VIP error : please palce the cursor on entity, component or instance line" | echohl None
    return ""
  endif
  for firstLineWord in firstLine
    if (firstLineWord ==? "entity") || (firstLineWord ==? "component") || (firstLineWord ==? "port" || (firstLineWord ==? "generic"))
      return firstLineWord
    endif
  endfor

  " Search for an instance under the current line
  let firstLine = split(getline(line(".") + 1))
  if ((firstLine[0] ==? "port") || (firstLine[0] ==? "generic"))
    return firstLine[0]
  endif
  echohl WarningMsg | echo "VIP error : please palce the cursor on entity, component or instance line" | echohl None
  return ""
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Yank an entity, a component or an instance
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:YankB()
  let yankBlock = []
  let blockType = s:CheckType() " check if we copy an entity, or a component, etc.
  if (blockType != "")
    let yankBlock = s:CopyLines(blockType)
  endif
  return [blockType,yankBlock]
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Action : what to do ? copy or paste / convert ?
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
function s:Action(actionToDo)
  " Copy
  if (a:actionToDo == "yank")
    let [s:VHDLType,s:VHDLBlock] = s:YankB()
    let s:instanceNumb = 0
    if ((s:VHDLType ==? "port") || (s:VHDLType ==? "generic"))
      let s:VHDLType = "instance"
    endif
    if s:VHDLBlock != []
      echo "VIP : ".s:VHDLType." copied"
    endif
  endif
  " Paste
  if s:VHDLBlock != []
    " Simple paste
    if (a:actionToDo == "paste")
      let result = s:SPaste(s:VHDLBlock)
    endif
    " Entity paste
    if (s:VHDLType ==? "entity")
      if (a:actionToDo == "entity")
        let result = s:SPaste(s:VHDLBlock)
      endif
      if (a:actionToDo == "component")
        let result = s:PasteEC(s:VHDLType, g:componentWord_VIP, s:VHDLBlock)
      endif
      if (a:actionToDo == "instance")
        let cleanBlock = s:CleanECI(s:VHDLBlock)
        if cleanBlock != []
          let result = s:PasteECI(s:instanceNumb, g:instPrefix_VIP, g:instSuffix_VIP, g:sigPrefix_VIP, cleanBlock)
          let s:instanceNumb += 1
        endif
      endif
    endif
    " Component paste
    if (s:VHDLType ==? "component")
      if (a:actionToDo == "entity")
        let result = s:PasteEC(s:VHDLType, g:entityWord_VIP, s:VHDLBlock)
      endif
      if (a:actionToDo == "component")
        let result = s:SPaste(s:VHDLBlock)
      endif
      if (a:actionToDo == "instance")
        let cleanBlock = s:CleanECI(s:VHDLBlock)
        if cleanBlock != []
          let result = s:PasteECI(s:instanceNumb, g:instPrefix_VIP, g:instSuffix_VIP, g:sigPrefix_VIP, cleanBlock)
          let s:instanceNumb += 1
        endif
      endif
    endif
    " Instance paste
    if s:VHDLType ==? "instance"
      if (a:actionToDo == "entity")
      endif
      if (a:actionToDo == "component")
      endif
      if (a:actionToDo == "instance")
        let result = s:PasteII(g:autoInc_VIP, s:instanceNumb, g:instSuffix_VIP, s:VHDLBlock)
        let s:instanceNumb += 1
      endif
    endif
  endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Main
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:VHDLBlock = [] " container for the block to be copied
let s:VHDLType = ""  " type of the block to copy
let s:instanceNumb = 0

if &expandtab == 1
  let s:indChar = " "
else
  let s:indChar = "\t"
endif
for s:inc in range(2, &shiftwidth)
  let s:indChar = s:indChar.s:indChar
endfor

"""""""""""""" Yank
if !hasmapto('<Plug>SpecialVHDLAction')
  map <unique> <leader>y <Plug>SpecialVHDLYank
endif
noremap <unique> <script> <Plug>SpecialVHDLYank <SID>Yank
noremap <SID>Yank :call <SID>Action("yank")<CR>

if !exists(":Viy")
  command -nargs=0 Viy :call s:Action("yank")
endif

"""""""""""""" Paste as same
if !hasmapto('<Plug>SpecialVHDLPaste')
  map <unique> <leader>p <Plug>SpecialVHDLPaste
endif
noremap <unique> <script> <Plug>SpecialVHDLPaste <SID>Paste
noremap <SID>Paste :call <SID>Action("paste")<CR>

if !exists(":Vip")
  command -nargs=0 Vip :call s:Action("paste")
endif

""""""""""""""" Paste as entity
if !hasmapto('<Plug>SpecialVHDLPasteEntity')
  map <unique> <leader>e <Plug>SpecialVHDLPasteEntity
endif
noremap <unique> <script> <Plug>SpecialVHDLPasteEntity <SID>PasteEntity
noremap <SID>PasteEntity :call <SID>Action("entity")<CR>

if !exists(":Vie")
  command -nargs=0 Vie :call s:Action("entity")
endif

""""""""""""""" Paste as component
if !hasmapto('<Plug>SpecialVHDLPasteComponent')
  map <unique> <leader>c <Plug>SpecialVHDLPasteComponent
endif
noremap <unique> <script> <Plug>SpecialVHDLPasteComponent <SID>PasteComponent
noremap <SID>PasteComponent :call <SID>Action("component")<CR>

if !exists(":Vic")
  command -nargs=0 Vic :call s:Action("component")
endif

""""""""""""""" Paste as instance
if !hasmapto('<Plug>SpecialVHDLPasteInstance')
  map <unique> <leader>i <Plug>SpecialVHDLPasteInstance
endif
noremap <unique> <script> <Plug>SpecialVHDLPasteInstance <SID>PasteInstance
noremap <SID>Paste Instance:call <SID>Action("instance")<CR>

if !exists(":Vii")
  command -nargs=0 Vii :call s:Action("instance")
endif

"vim:ff=unix
