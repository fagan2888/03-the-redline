# Exploratory Data Analysis Shiny App for Redline BLS data.
# The filename app.R is required by Shiny.

library(utils)
library(data.table)
library(rvest) # XML/HTML handling
library(rdrop2) # Dropbox wrapper
library(shiny)

library(shinyTree)

source('MakeCodeTree.R')
source('CondLoadDataTable.R')

# Globals are first computed or just plain set to parameterize behavior.

HeadTailN = 10 # Initial value to seed the GUI.

hostname = system('hostname', intern=T)

if (hostname == 'AJ')
{
    MaxRowsToRead <<- 10000 # data max is less than 50M
    DDLRoot = 'E:/wat/misc/DDL'
    DataDir = paste0(DDLRoot,'/Data')
} else
{
    MaxRowsToRead <<- 100000000 # data max is less than 50M so this gets all
}
if (hostname == 'VM-EP-3')
{
    DDLRoot = 'd:/RProjects' # Oops
    DataDir = paste0(DDLRoot,'/RedLineData')
}
ForceListRLFilesFromDropBox = F # T to locally test DropBox connectivity
if (!ForceListRLFilesFromDropBox & (hostname == 'VM-EP-3' | hostname == 'AJ'))
{
    ListRLFilesFromDropBox = FALSE # Local only
    QuietDownload <<- FALSE
} else
{
    DataDir = 'Data'
    ListRLFilesFromDropBox = TRUE # Any local cache is still used for the actual data
    QuietDownload <<- TRUE
}
OrigDataDir <<- paste0(DataDir,'/BLSOrig')
CompressedRDataDir <<- paste0(DataDir,'/CompressedRDA')
dir.create(OrigDataDir,recursive=T,showWarnings=F)
dir.create(CompressedRDataDir,recursive=T,showWarnings=F)

# If we don't have the data locally, check DropBox using these globals.

DropBoxDataDir = '/Data'
DropBoxCompressedRDataDir <<- paste0(DropBoxDataDir,'/CompressedRDA')
# This works around an apparent limitation of publishing to shinyapps.io:
if (!file.exists('.httr-oauth') & file.exists('httr-oauth')) {file.rename('httr-oauth','.httr-oauth')}

# Cache the filelist from BLS into FNsB

BLSDataURL <<- 'http://download.bls.gov/pub/time.series/cs'

FileListRaw = read_html(BLSDataURL)
FileList = (FileListRaw %>% html_nodes('a') %>% html_text())

FNsB = c()
for(FileName in FileList[2:length(FileList)]) # [1] is [To Parent Directory]
{
    if (FileName %in% c('cs.contacts','cs.txt','cs.data.0.Current')) next # These do not contain tabular data or duplicate other files.

    FNsB[length(FNsB)+1] = FileName
} # for

# Cache the RedLine data filelist into FNsR

if (ListRLFilesFromDropBox)
{
    # List the directory, stipping off the pathname from each filename
    FNsR = sub(paste0(DropBoxCompressedRDataDir,'/'),'',drop_dir(DropBoxCompressedRDataDir,n=0)$path)
    FNsR = grep('^rl[.].*rda',FNsR,value=T,ignore.case=T) # Filter, keeping just the rl datafiles
    FNsR = sub('[.]rda','',FNsR) # Remove .rda to make the name look better in the GUI.
} else
{
    FNsR = dir(CompressedRDataDir,'^rl[.].*rda')
    FNsR = sub('[.]rda','',FNsR) # Remove .rda to make the name look better in the GUI.
}

FNsT = list(
#         rl.category='', # Doesn't work yet; don't know why
        rl.industry='',
        rl.event='', # Want industry to be the default so show selected works
        rl.nature='',
#        rl.occupation='', # Doesn't work yet; 17 'roots' but so far only 1 is supported
        rl.pob='',
        rl.source=''
            )

FNsS = list(
#         rl.category='', # Doesn't work yet; don't know why
        rl.industry4='',
        rl.event4='', # Want industry to be the default so show selected works
        rl.nature4='',
#        rl.occupation='', # Doesn't work yet; 17 'roots' but so far only 1 is supported
        rl.pob4='',
        rl.source4=''
            )

FNsP = list(
        rl.industry4=''
            )

CondLoadDataTable('SeriesYearIndustryCounts')

# Define UI for dataset viewer application.

ui = fluidPage(
    tabsetPanel
    (
        type = "tabs",
        tabPanel
        (
            'Injury Predictions by Industry',
            sidebarLayout
            (
                sidebarPanel
                (
                    selectInput('datasetP', 'Choose a data.table:',
                                choices = names(FNsP)),
                    numericInput('yearsP','Number of years to predict:',3,min=1,max=9)
                ),
                mainPanel
                (
                    h3('Injuries (Series) by Year for the Selected Industry'),
                    plotOutput('plot1P'),
                    h3('Currently Selected:'),
                    verbatimTextOutput('selTxtP'),
                    hr(),
                    shinyTree('treeP')
                )
            )
        ), # tabPanel - P
        tabPanel
        (
            'More Documentation',
            titlePanel('Application Documentation and Background'),
            br(),
            'Each year, the United States Bureau of Labor Statistics (BLS) makes available',
            'scores of GB of data on occupational injuries.',
            'The data is available at',
            tags$a(href='http://download.bls.gov/pub/time.series/cs',target='_blank','download.bls.gov/pub/time.series/cs'),
            'and data documentation',
            'is available in the file cs.txt at that location. Even more documentation is at',
            tags$a(href='http://www.bls.gov/iif/oiics_manual_2010.pdf',target='_blank','www.bls.gov/iif/oiics_manual_2010.pdf'),
            '. Briefly, injury series are recorded with many',
            'dimensions such as year(s), age (range), and industry, to name a few.',
            br(),br(),
            'This application lets the user explore injuries by year for a chosen industry',
            'or industry group. The application',
            'displays a plot of the chosen data to help elucidate the trend in the chosen data.',
            'To make the trend clear, the plot shows both the actual BLS data and a linear prediction',
            'for the years following those available in the BLS data.',
            'The actual BLS injury series counts are in black and the predicted injury series counts are in red.',
            br(),br(),
            'There are two user controls. The first is a text entry box that lets the user choose how',
            'many years forward to predict.',
            'The supported number of years to predict is between 1 and 9 inclusive.',
            'The second lets the user choose a focus industry',
            'or industry group by walking',
            'a hierarchy that starts with all injured workers and gets more specific as the user',
            tags$i('walks'),'towards',
            'the leaves of the industry hierarchy tree.',
            br(),br(),
            'The industry hierarchy tree can be opened or closed by clicking on the triangle to left of each industry (category).',
            'The user indicates a selection for plotting by clicking on the text of the industry (group) itself.',
            'To provide adequate performance to the user, the depth of the industry hierarchy has been',
            'limited and the summary counts have been precalculated by year and industry.',
            br(),br(),
            'When walking the tree, the user can click a white triangle to open its',
            'respective node and view deeper hierarchy levels. When',
            'a node is open, click the black triangle to close it.',
            'Nodes without triangles have no deeper hierarchy levels.',
            'These are leaf nodes and may correspond to an industry or a BLS grouping of',
            'of industries. The non leaf nodes always correspond to industry groups.',
            br(),br(),
            '(Left) click on the', tags$b('Injury Predictions by Industry'),'tab in the upper left to return to the application.',
            br(),br(),
            'The source code for this application is available for review at the',
            tags$a(href='https://github.com/WatHughes/03-the-redline',
                   target='_blank','GitHub Private Repo'),
            'for this application.',
            br(),br(),
            'To calculate the predictions, first the selected data points (specified by',
            'the tree control)',
            "are fed to R's lm()",
            'function. The resulting model is then fed to predict() along with the list of years',
            'that the user specified (indirectly, with the text input control).',
            br(),br()
        ), # tabPanel - Doc
        tabPanel
        (
            'BLS Datafiles',
            sidebarLayout
            (
                sidebarPanel
                (
                    selectInput('datasetB', 'Choose a datafile:',
                                choices = FNsB),
                    numericInput('obsB','Number of observations to view:',10,min=1)
                ),
                mainPanel
                (
                    h3('Data Structure'),
                    verbatimTextOutput('strB'),
                    h3('Head'),
                    tableOutput('viewB')
                )
            )
        ),
        tabPanel
        (
            'RedLine Datafiles',
            sidebarLayout
            (
                sidebarPanel
                (
                    selectInput('datasetR', 'Choose a datafile:',
                                choices = FNsR),
                    numericInput('obsR','Number of observations to view:',10,min=1)
                ),
                mainPanel
                (
                    h3('Data Structure'),
                    verbatimTextOutput('strR'),
                    h3('Summary'),
                    verbatimTextOutput('summaryR'),
                    h3('Head'),
                    tableOutput('viewR')
                )
            )
        ),
        tabPanel
        (
            'Sample Tree Control for a BLS Code Table Hierarchy',
            sidebarLayout
            (
                sidebarPanel
                (
                    selectInput('datasetT', 'Choose a data.table:',
                                choices = names(FNsT))
                ),
                mainPanel
                (
                    h3('Data Structure'),
                    verbatimTextOutput('strT'),
                    h3('Currently Selected:'),
                    verbatimTextOutput('selTxtT'),
                    hr(),
                    shinyTree('treeT')
                )
            )
        ), # tabPanel - T
        tabPanel
        (
            'Sample Tree Control for Depth Limited BLS Code Trees',
            sidebarLayout
            (
                sidebarPanel
                (
                    selectInput('datasetS', 'Choose a data.table:',
                                choices = names(FNsS))
                ),
                mainPanel
                (
                    h3('Data Structure'),
                    verbatimTextOutput('strS'),
                    h3('Currently Selected:'),
                    verbatimTextOutput('selTxtS'),
                    hr(),
                    shinyTree('treeS')
                )
            )
        ) # tabPanel - S
    ) # tabsetPanel
) # ui

# Define server logic required to summarize and view the selected
# dataset
server = function(input, output)
{
    # By declaring datasetInput as a reactive expression we ensure
    # that:
    #  1) It is only called when the inputs it depends on changes
    #  2) The computation and result are shared by all the callers
    #	  (it only executes a single time)
    datasetInputB = reactive({
        CondLoadDataTable(input$datasetB)
    })
    # The output$str depends on the datasetInput reactive
    # expression, so will be re-executed whenever datasetInput is
    # invalidated
    # (i.e. whenever the input$dataset changes)
    output$strB = renderPrint({
        dataset = datasetInputB()
        str(dataset)
    })
    # The output$view depends on both the databaseInput reactive
    # expression and input$obs, so will be re-executed whenever
    # input$dataset or input$obs is changed.
    output$viewB = renderTable({head(datasetInputB(), n = input$obsB)})
    # RedLine Data
    datasetInputR = reactive({
        CondLoadDataTable(input$datasetR)
    })
    output$strR = renderPrint({
        dataset = datasetInputR()
        str(dataset)
    })
    output$summaryR = renderPrint({
        dataset = datasetInputR()
        summary(dataset)
    })
    output$viewR = renderTable({head(datasetInputR(), n = input$obsR)},include.rownames=F)

    # Code Tree Hierarchy
    datasetInputT = reactive({
        CondLoadDataTable(input$datasetT)
    })
    output$strT = renderPrint({
        dataset = datasetInputT()
        str(dataset)
    })

    output$treeT <- renderTree({
        datasetname = input$datasetT
        ct = FNsT[[datasetname]]
        if (!is.list(ct))
        {
            ct = MakeCodeTree(get(datasetname))
            FNsT[[datasetname]] <<- ct
        }
        DisplayTree = ct$GetDisplayTree()
        # browser() # Breakpoints seem flaky in Shiny
        DisplayTree
    })
    output$selTxtT <- renderText({
        datasetname = input$datasetT # Reactive dependency -- doesn't work.
        tree = input$treeT
        if (is.null(tree))
        {
            'None'
        } else
        {
            sel = get_selected(tree)
            # List of 1 # Names format: list of 1 where name is the selected and path in the attributes
            #  $ : atomic [1:1] Public administration
            #   ..- attr(*, "ancestry")= chr [1:2] "All workers" "Service-providing"
            ss = unlist(sel)
            if (is.null(ss))
            {
                selTxtT = 'Nothing selected.'
            }
            else if(T)
            {
                selTxtT = ss
            } # Below here is WIP
            else if(is.na(as.integer(ss)))
            {
                selTxtT = paste0('Cannot find sort_sequence ',ss)
            }
            else
            {
                ct = FNsT[[1]]
                DisplayTextColumn = ct$GetDisplayTextColumn()
                adt = ct$GetAugmentedCodeData()
                selTxtT = adt[as.integer(ss),DisplayTextColumn,with=F]
            }
            selTxtT
        }
    })

    # Truncated Code Tree Hierarchy
    datasetInputS = reactive({
        CondLoadDataTable(input$datasetS)
    })
    output$strS = renderPrint({
        ds = datasetInputS() # For the reactivity
        dataset = datasetInputS()
        str(dataset)
    })

    output$treeS <- renderTree({
        ds = datasetInputS() # For the reactivity
        datasetname = input$datasetS
        ct = FNsS[[datasetname]]
        if (!is.list(ct))
        {
            ct = MakeCodeTree(get(datasetname),4) # display_level >= 4 will be ignored
            FNsS[[datasetname]] <<- ct
        }
        DisplayTree = ct$GetDisplayTree()
        # browser() # Breakpoints seem flaky in Shiny
        DisplayTree
    })
    output$selTxtS <- renderText({
        ds = datasetInputS() # For the reactivity
        datasetname = input$datasetS
        tree = input$treeS
        if (is.null(tree))
        {
            'None'
        } else
        {
            sel = get_selected(tree,format='slices')
            # List of 1 # Slices Format: all lists, no attributes.
            #  $ :List of 1
            #   ..$ All workers:List of 1
            #   .. ..$ Service-providing:List of 1
            #   .. .. ..$ Professional and business services: num 0
            ct = FNsS[[datasetname]]
            CodeDef = ct$GetSelectedCodeDef(sel)
            DisplayTextColumn = ct$GetDisplayTextColumn()
            CodeColumn = ct$GetCodeColumn()
            if (is.null(CodeDef))
            {
                selTxtS = 'Nothing selected'
            }
            else
            {
                selTxtS = paste0(CodeDef[1,CodeColumn,with=F],':  ',CodeDef[1,DisplayTextColumn,with=F])
            }
            selTxtS
        }
    })

    # Injury Predictions by Industry
    datasetInputP = reactive({
        CondLoadDataTable(input$datasetP)
    })

    output$plot1P = renderPlot({
        ds = datasetInputP() # For the reactivity
        selTxtP = SelectionDisplayText()
        selCodeP = sub(':.*','',selTxtP)
        selData = SeriesYearIndustryCounts[industry_code==selCodeP]
        if (nrow(selData) > 0)
        {
            selMod = lm(N~year,data=selData)
            predCount = input$yearsP
            predYears = data.frame(year=c(1:predCount))
            predYears$year = predYears$year + 2013
            selPred = predict(selMod,predYears)
            df=data.frame(year=c(selData$year,predYears$year),SeriesCount=c(selData$N,selPred),DataOrPrediction=as.factor(c(rep(1,3),rep(2,predCount))))
            plot(SeriesCount~year,data=df,col=DataOrPrediction,pch=9,cex=2,xlab='Year. BLS data in black and predictions in red.',ylab='Series Count')
        }
    })
    output$treeP <- renderTree({
        ds = datasetInputP() # For the reactivity
        datasetname = input$datasetP
        ct = FNsP[[datasetname]]
        if (!is.list(ct))
        {
            ct = MakeCodeTree(get(datasetname),4) # display_level >= 4 will be ignored
            FNsS[[datasetname]] <<- ct
        }
        DisplayTree = ct$GetDisplayTree()
        # browser() # Breakpoints seem flaky in Shiny
        DisplayTree
    })
    SelectionDisplayText = reactive({
        ds = datasetInputP() # For the reactivity
        datasetname = input$datasetP
        tree = input$treeP
        if (is.null(tree))
        {
            'None'
        } else
        {
            sel = get_selected(tree,format='slices')
            # List of 1 # Slices Format: all lists, no attributes.
            #  $ :List of 1
            #   ..$ All workers:List of 1
            #   .. ..$ Service-providing:List of 1
            #   .. .. ..$ Professional and business services: num 0
            ct = FNsS[[datasetname]]
            CodeDef = ct$GetSelectedCodeDef(sel)
            DisplayTextColumn = ct$GetDisplayTextColumn()
            CodeColumn = ct$GetCodeColumn()
            if (is.null(CodeDef))
            {
                selTxtP = 'Nothing selected'
            }
            else
            {
                selTxtP = paste0(CodeDef[1,CodeColumn,with=F],':  ',CodeDef[1,DisplayTextColumn,with=F])
            }
            selTxtP
        }
    })
    output$selTxtP <- renderText({
        selTxtP = SelectionDisplayText()
    })

} # server

shinyApp(ui, server)
