groupsoverview_UI <- function(id) {
    ns <- NS(id)
    
    tagList(
        titleBox("iAtlas Explorer — Sample Groups Overview"),
        textBox(
            width = 12,
            p("This module provides short summaries of your selected groups and allows you to see how they overlap with other groups."),
            p("You can also upload your own, custom-grouped samples, which will then allow you to compare immune response among those sample groups. Following this upload, your custom groupings will be available through Select Sample Groups (left navigation panel), along with the pre-defined groups."),
            p(""),
            p("Sample Groups are used in all plots, using the short labels. Please refer back to this current module for reminders of those labels.")
        ),
        sectionBox(
            title = "Custom Groups",
            collapsed = TRUE,
            messageBox(
                width = 12,
                p("Upload a comma-separated table with your own sample/group assignments to use in iAtlas analysis modules.")  
            ),
            fluidRow(
                optionsBox(
                    width = 12,
                    tags$head(tags$script(src = "message-handler.js")),
                    actionButton(ns("filehelp"), 
                                 " Formatting instructions",
                                 icon = icon("info-circle")),
                    hr(),
                    fileInput(
                        ns("file1"),
                        "Choose CSV File",
                        multiple = FALSE,
                        accept = c("text/csv",
                                   "text/comma-separated-values,text/plain",
                                   ".csv")
                    )
                )
            ),
            messageBox(
                width = 12,
                p("After uploading your file, the table below will show your defined groups."),
                DT::dataTableOutput(
                    ns("user_group_df")
                )
            )
        ),
        data_table_module_UI(
            ns("sg_table"),
            title = "Group Key",
            message_html = p(stringr::str_c(
                "This displays attributes and annotations of your choice of",
                "groups.",
                sep = " "
            ))
        ),
        # sectionBox(
        #     title = "Group Key",
        #     messageBox(
        #         width = 12,
        #         p("This displays attributes and annotations of your choice of groups.")  
        #     ),
        #     fluidRow(
        #         tableBox(
        #             width = 12,
        #             title = textOutput(ns("sample_group_name")),
        #             div(style = "overflow-x: scroll",
        #                 DT::dataTableOutput(ns("sample_group_table")) %>% 
        #                     shinycssloaders::withSpinner()
        #             )
        #         )
        #     )
        # ),
        sectionBox(
            title = "Group Overlap",
            messageBox(
                width = 12,
                p("This displays the overlap between the grouping you are looking at (“first” sample grouping), and an alternate grouping (“second” sample grouping), as a so-called mosaic plot.  In the mosaic plot, each column represents grouping by the alternate method, and the proportion of samples falling into your primary group choice are shown proportionally within that column. The width of the column reflects the number of samples in the alternate groups."), 
                p("Manuscript context: Figure 1D can be generated by selecting Immune Subtype in the top left as the primary group, and “TCGA Study” with the radio buttons below, as the alternate grouping. Figure S1B corresponds to the opposite choice, and you can generate a mosaic plot for the BRCA subtypes in Figure S1B using this method.")
            ),
            fluidRow(
                optionsBox(
                    width = 8,
                    uiOutput(ns("mosaic_group_select"))
                ),
                uiOutput(ns("study_subset_select"))
            ),
            fluidRow(
                plotBox(
                    width = 12,
                    column(
                        width = 12,
                        plotlyOutput(ns("mosaicPlot"), height = "600px") %>% 
                            shinycssloaders::withSpinner()
                    )
                )
            )
        )
    )
}


    
groupsoverview <- function(
    input, 
    output, 
    session, 
    group_display_choice, 
    group_internal_choice,
    sample_group_df,
    subset_df, 
    plot_colors, 
    group_options, 
    width
){
    ns <- session$ns
    
    # reactives ----
    
    user_group_df <- reactive({
        if(is.null(input$file1$datapath)){
            return(NA)
        }
        result <- try(readr::read_csv(input$file1$datapath))
        if(is.data.frame(result)){
            return(result)  
        } else {
            return(NA)
        }
    })
    
        
    # ui ----
    
    
    
    output$mosaic_group_select <- renderUI({
        choices <- setdiff(group_options(), 
                           group_display_choice())
        radioButtons(ns("sample_mosaic_group"), 
                     "Select second sample group to view overlap:",
                     choices = choices,
                     selected = choices[1],
                     inline = TRUE)
    })
    
    output$study_subset_select <- renderUI({
        req(input$sample_mosaic_group, panimmune_data$sample_group_df, cancelOutput = TRUE)
        if (input$sample_mosaic_group == "TCGA Subtype") {
            choices <- panimmune_data$sample_group_df %>% 
                dplyr::filter(sample_group == "Subtype_Curated_Malta_Noushmehr_et_al") %>% 
                dplyr::select("FeatureDisplayName", "TCGA Studies") %>% 
                dplyr::distinct() %>% 
                dplyr::arrange(`TCGA Studies`) %>%
                tibble::deframe()
            
            
            
            optionsBox(
                width = 4,
                selectInput(ns("study_subset_selection"), 
                            "Choose study subset:",
                            choices = choices,
                            selected = names(choices[1])))
            
            }
    })
    
    # other ----
    
    observeEvent(input$filehelp, {
        showModal(modalDialog(
            title = "Formatting custom groups",
            includeMarkdown("data/user_groups.md"),
            size = "l", easyClose = TRUE
        ))})
    
    output$sample_group_name <- renderText({
        paste(group_display_choice(), "Groups")
    })
    
    output$user_group_df <- DT::renderDataTable({
        
        req(!is.na(user_group_df()), cancelOutput = T)
        user_group_df()
    })
        
    
    table_df <- reactive({
        
        req(subset_df(), 
            group_internal_choice(),
            sample_group_df(),
            plot_colors(),
            cancelOutput = T)
        
        build_sample_group_key_df(
                group_df = subset_df(),
                group_column = group_internal_choice(),
                feature_df = sample_group_df())
    })
    
    callModule(
        data_table_module, 
        "sg_table", 
        table_df,
        options = list(
            dom = "tip",
            pageLength = 10,
            columnDefs = list(
                list(width = '50px',
                     targets = c(1)))),
        color = T,
        color_column = "Plot Color",
        colors = plot_colors())
    
    # plots ----
    
    output$mosaicPlot <- renderPlotly({
        
        req(subset_df(),
            group_display_choice(),
            group_internal_choice(),
            input$sample_mosaic_group,
            input$sample_mosaic_group != group_display_choice(),
            !is.null(user_group_df()),
            sample_group_df(),
            plot_colors(),
            cancelOutput = T)
        
        display_x  <- input$sample_mosaic_group
        display_y  <- group_display_choice()
        internal_x <- get_group_internal_name(display_x)
        internal_y <- group_internal_choice()
        
        mosaic_df <- build_group_group_mosaic_plot_df(
            subset_df(),
            internal_x,
            internal_y,
            user_group_df(),
            sample_group_df(),
            input$study_subset_selection) 
        
        validate(
            need(nrow(mosaic_df) > 0, "Group choices have no samples in common"))
        
        create_mosaicplot(
            mosaic_df,
            title = stringr::str_c(display_y, "by", display_x, sep = " "),
            fill_colors = plot_colors()) 
    })
    
    return(user_group_df)
    
}

