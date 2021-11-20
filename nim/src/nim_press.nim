import
  os,
  strutils,
  re,
  markdown,
  std/strformat,
  templates

type
  Link = object
    href: string
    name: string
  Navigation = object
    parents: seq[Link]
    siblings: seq[Link]
    children: seq[Link]
  Node = object
    name: string
    content: string
    nav: Navigation
  Layout = object
    post: string
    parents: string
    siblings: string
    children: string

proc getWikiTree(mdDir: string): seq[Node] =
  for f in walkDirRec(mdDir):
    result.add(Node(name: relativePath(f, mdDir), content: readFile(f)))

func setOutputName(tree: seq[Node]): seq[Node] =
  for n in tree:
    result.add(Node(name: n.name.replace(".md", ".html"), content: n.content, nav: n.nav))

proc setNav(tree: seq[Node]): seq[Node] =
  # siblings
  for n in tree:
    let parentOfN = parentDir(n.name)
    var siblings: seq[Link]
    for n_2 in tree:
      if (parentDir(n_2.name) == parentOfN):
        siblings.add(Link(href: n_2.name.replace(".md", ".html"), name: findAll(n_2.name, re"[^\/]*\.md")[0][0..^4]))
    result.add(Node(name: n.name, content: n.content, nav: Navigation(siblings: siblings)))

  # children
  let new_tree = result
  result = @[]

  for n in new_tree:
    let nAsParent = n.name[0..^4]
    var children: seq[Link]
    for n_2 in new_tree:
      if (parentDir(n_2.name) == nAsParent):
        children.add(Link(href: n_2.name.replace(".md", ".html"), name: findAll(n_2.name, re"[^\/]*\.md")[0][0..^4]))
    result.add(Node(name: n.name, content: n.content, nav: Navigation(siblings: n.nav.siblings, children: children)))

  # parents
  let parent_tree = result
  result = @[]

  for n in parent_tree:
    let parentOfN = parentDir(n.name)
    if (parentOfN == ""):
      result.add(n)
    else:
      let grandParentOfN = parentDir(parentOfN)
      var parents: seq[Link]
      for n_2 in parent_tree:
        if (n_2.name.parentDir() == grandParentOfN):
          parents.add(Link(href: n_2.name.replace(".md", ".html"), name: findAll(n_2.name, re"[^\/]*\.md")[0][0..^4]))
      result.add(Node(name: n.name,
                      content: n.content,
                      nav: Navigation(siblings: n.nav.siblings,
                                      children: n.nav.children,
                                      parents: parents)))

proc convertToHtml(tree: seq[Node]): seq[Node] =
  for n in tree:
    result.add(Node(name: n.name, nav: n.nav, content: markdown(n.content)))

func layoutTemplate(layout: Layout, htmlStr: string): string =
  return htmlStr.replace("{layout.post}", layout.post)
                .replace("{layout.parents}", layout.parents)
                .replace("{layout.siblings}", layout.siblings)
                .replace("{layout.children}", layout.children)

proc putHtmlInLayout(tree: seq[Node], layoutHtml: string): seq[Node] =
  for n in tree:
    var
      parents: string
      siblings: string
      children: string

    if n.nav.parents.len() != 0:
      parents.add("""<div class="parents">""")
      for l in n.nav.parents:
        parents.add(fmt"<a href='/{l.href}'>{l.name}</a>")
      parents.add("""</div>""")

    siblings.add("""<div class="siblings">""")
    for l in n.nav.siblings:
      if l.href == n.name:
        siblings.add(fmt"""<a class="here" href='/{l.href}'>{l.name}</a>""")
      else:
        siblings.add(fmt"<a href='/{l.href}'>{l.name}</a>")
    siblings.add("""</div>""")

    children.add("""<div class="children">""")
    for l in n.nav.children:
      children.add(fmt"<a href='/{l.href}'>{l.name}</a>")
    children.add("""</div>""")

    let
      layout = Layout(post: n.content, parents: parents, siblings: siblings, children: children)
      newContent = layoutTemplate(layout, layoutHtml)
    result.add(Node(name: n.name, content: newContent, nav: n.nav))

proc main() =
  echo("What is your input directory containing md files: ")
  var
    inputValid = false
    input: string
  while not inputValid:
    input = readLine(stdin)
    try:
      if (getFileInfo(input).kind == PathComponent.pcDir):
        inputValid = true
    except Exception as e:
      echo(e.msg)

  echo("What is your output directory (CAUTION: this directory will be erased): ")
  var
    outputValid = false
    output: string
  while not outputValid:
    output = readLine(stdin)
    try:
      if (getFileInfo(output).kind == PathComponent.pcDir) and (output != input):
        outputValid = true
    except Exception as e:
      echo(e.msg)

  echo("What is your layout file: ")
  var
    layoutValid = false
    layoutFile: string
  while not layoutValid:
    layoutFile = readLine(stdin)
    try:
      if (getFileInfo(layoutFile).kind == PathComponent.pcFile):
        layoutValid = true
    except Exception as e:
      echo(e.msg)

  let
    layoutHtml = readFile(layoutFile)
    inputTree = getWikiTree(input)
                  .setNav()
                  .setOutputName()
                  .convertToHtml()
                  .putHtmlInLayout(layoutHtml)

  for n in inputTree:
    let
      outFile = joinPath(output, n.name)
      content = n.content
    try:
      writeFile(outFile, content)
    except IOError:
      createDir(parentDir(outFile))
      writeFile(outFile, content)

  quit(0)

when isMainModule:
  main()
