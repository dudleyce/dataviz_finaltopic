library(tidyverse)
library(plotly)
library(shinythemes)
library(DT)
library(expss)

# putting together all of the seasons
coefs <- read_csv("data/coefs2017.csv")
model_df <- read_csv("data/model_subset.csv")

coefs16 <- read_csv("data/coefs2016.csv")
model_df16 <- read_csv("data/model_subset16.csv")

coefs18 <- read_csv("data/coefs2018.csv")
model_df18 <- read_csv("data/model_subset18.csv")

coefs19 <- read_csv("data/coefs2019.csv")
model_df19 <- read_csv("data/model_subset19.csv")

coefs21 <- read_csv("data/coefs2021.csv")
model_df21 <- read_csv("data/model_subset21.csv")

coefs22 <- read_csv("data/coefs2022.csv")
model_df22 <- read_csv("data/model_subset22.csv")

coefs <-
  coefs %>%
  mutate(Season = "2017-18")
coefs16 <-
  coefs16 %>%
  mutate(Season = "2016-17")
coefs18 <-
  coefs18 %>%
  mutate(Season = "2018-19")
coefs19 <-
  coefs19 %>%
  mutate(Season = "2019-20")
coefs21 <-
  coefs21 %>%
  mutate(Season = "2020-21")
coefs22 <-
  coefs22 %>%
  mutate(Season = "2021-22")
model_df <-
  model_df %>%
  mutate(Season = "2017-18")
model_df16 <-
  model_df16 %>%
  mutate(Season = "2016-17")
model_df18 <-
  model_df18 %>%
  mutate(Season = "2018-19")
model_df19 <-
  model_df19 %>%
  mutate(Season = "2019-20")
model_df21 <-
  model_df21 %>%
  mutate(Season = "2020-21")
model_df22 <-
  model_df22 %>%
  mutate(Season = "2021-22")

total_coefs <-
  rbind(coefs16, coefs, coefs18, coefs19, coefs21, coefs22)
total_modeldf <-
  rbind(model_df16, model_df, model_df18, model_df19, model_df21, model_df22)

# fix the team names
total_coefs <-
  total_coefs %>%
  mutate(Team = substr(Team, 29, 40))

# get correct amount of days in dataset
total_coefs <-
  total_coefs %>%
  mutate(daysafterdeadline = case_when(Season == "2019-20"~ 16,
                                       Season == "2018-19" ~ 40,
                                       Season == "2017-18" ~ 40,
                                       Season == "2016-17" ~ 40,
                                       Season == "2020-21" ~ 32,
                                       Season == "2021-22" ~ 36),
         daysbeforedeadline = ifelse(Season == "2020-21", -89, -150))

# App

teams <- levels(factor(total_modeldf$HomeTeam))


library(shiny)

ui <- fluidPage(
  titlePanel("Quantifying NHL Trade Deadline Winners and Losers"),
  theme = shinytheme("yeti"),
  sidebarLayout(
    sidebarPanel(selectizeInput(inputId = "teamchoice",
                                label = "Choose a Team",
                                choices = teams,
                                selected = "Boston"),
                 radioButtons(inputId = "yearselect",
                              label = "Choose a Season",
                              choices = levels(factor(total_coefs$Season)))),
    mainPanel(plotlyOutput(outputId = "majorplot"),
              tableOutput(outputId = "table1"))
  ))

server <- function(input, output, session) {
  
  model_update <- reactive({
    total_modeldf <-
      total_modeldf %>%
      filter(Season == input$yearselect) %>%
      mutate(Teams = paste(HomeTeam, ",", AwayTeam)) %>%
      filter(str_detect(Teams, input$teamchoice)) %>%
      mutate(BoundaryProb = ifelse(HomeTeam == input$teamchoice,
                                   BoundaryProbHome2, BoundaryProbAway2),
             OpposingTeam = str_remove(Teams, input$teamchoice)) %>%
      mutate(OpposingTeam = trimws(OpposingTeam, which = c("both"))) %>%
      mutate(OpposingTeam = gsub(",","",OpposingTeam)) %>%
      mutate(Back2Back = ifelse(HomeTeam == input$teamchoice,
                                Back2BackHome, Back2BackAway)) %>%
      mutate(Back2Back = as.logical(Back2Back)) 
  })
  

  
  coef_update <- reactive({
    total_coefs <-
      total_coefs %>%
      filter(Season == input$yearselect,
             Team == input$teamchoice)
  })
  
  coef_order1 <- reactive({
    total_coefs <-
      total_coefs %>%
      filter(Season == input$yearselect) %>%
      slice_max(diffat0, n = 5) %>%
      select(Team, diffat0) %>%
      rename("Winners at 0" = diffat0)
  })
  
  coef_order2 <- reactive({
    total_coefs <-
      total_coefs %>%
      filter(Season == input$yearselect) %>%
      slice_min(diffat0, n = 5) %>%
      select(Team, diffat0) %>%
      rename("Losers at 0" = diffat0)
  })
  
  coef_order3 <- reactive({
    total_coefs <-
      total_coefs %>%
      filter(Season == input$yearselect) %>%
      slice_max(diffat40, n = 5) %>%
      select(Team, diffat40) %>%
      rename("Winners at End of Season" = diffat40)
  })
  
  coef_order4 <- reactive({
    total_coefs <-
      total_coefs %>%
      filter(Season == input$yearselect) %>%
      slice_min(diffat40, n = 5) %>%
      select(Team, diffat40) %>%
      rename("Losers at End of Season" = diffat40)
  })
  
  plot1 <- reactive({ggplot(data = model_update(), aes(x = DeadlineDays, y = BoundaryProb,
                                             label = OpposingTeam)) +
    geom_point(aes(color = model_update()$Back2Back)) +
    geom_segment(aes(x = coef_update()$daysbeforedeadline, 
                     y = coef_update()$main_intercept +
                       coef_update()$intercept + 
                       (-150 * (coef_update()$DeadlineDays + coef_update()$deadline_days)),
                     xend = 0, yend = coef_update()$main_intercept +
                       coef_update()$intercept)) +
    geom_segment(aes(x = -0, 
                     y = coef_update()$main_intercept +
                       coef_update()$intercept + 
                       coef_update()$DeadlineInd +
                       coef_update()$deadline_indicator, 
                     xend = coef_update()$daysafterdeadline, 
                     yend = coef_update()$predictedend
    )) +
      scale_color_brewer(palette = "Set1") +
    geom_vline(xintercept = 0, linetype = "dotted",
               color = "pink") +
    theme_classic() +
      theme(text = element_text(size = 14)) +
    labs(x = "Days Relative to the Trade Deadline",
         y =  "Vegas's Predicted Probability of Winning",
         title = input$teamchoice, 
         color = "Back to Back Game")
  })
  
  
  
  output$majorplot <- renderPlotly({
    validate(
      need(coef_update() > 1, paste('Sorry, you chose a year where', input$teamchoice,
           'did not exist!'))
    )
    validate(need(model_update() > 1, paste('Sorry, you chose a year where', input$teamchoice,
                  'did not exist!')))
    ggplotly(plot1(), tooltip = "label")
    
  })
  
  
  
  output$table1 <- renderTable({cbind(coef_order1(),
                                      coef_order2(),
                                      coef_order3(),
                                      coef_order4())
    
  }, caption = paste("The table above displays the top 5 'winners' and 'losers' at 
     and after the trade deadline. The variable diffat0 refers to the difference in
                    the two lines at the trade deadline (day 0) and the variable
                    diffat40 shows the difference between where the first line would
                    have ended up and where the second line ends up at the end
                    of the regular season. These two variables are what we used
                    to measure how well teams did at the deadline.")
 )
  
}

shinyApp(ui, server)