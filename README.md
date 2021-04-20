# Introduction 
This repository hosts the starting solution for potential engineers to review and evaluate for discussion during the technical interview sessions

# Getting Started
There are two projects in this solution.
1. An API that provides the ability to query the NY Taxi dataset directly in BigQuery
2. An example of a frontend built in React that uses the API to present the dataset

# API
The `Backend` project is an ASP.NET Core API Project.

The API consists of a single controller with the controller providing two slightly different types of endpoint:
1. The first handles the large set of data points by returning the data in aggregate (grouped)
2. The second returns individual datapoints

# Frontend
## Dependencies
- Node.js
- yarn
- `create-react-app` yarn package and Dependencies

The 'Frontend' project is a React App and should be run with `yarn`.
To run the frontend project (after instaling the dependencies above):
- `yarn add create-react-app` (You only need to run this once)
- `yarn start`

The source can be reviewed using your favourite text editor.

# Note
The API Key for Google is invalid, an API Key will be provided to you that you should use instead of the key defined in the `.env` file.
If you have your own Google API Key feel free to use that.

# Task
1. Review both projects
2. Have the solution running and working on your own laptop that you should bring with you to the technical interview sessions
3. Create a list of issues / concerns / opinions on the solution. The items should be a mixture of architectural, design and code level issues
4. Be prepared to discuss your concerns and reasons why you have those concerns

# Technical interview
During the technical interview you will be asked to:
1. present your findings and show, by way of opening the code and pointing out specific aspects, errors or concerns you have.
2. make a selection of changes to the solution potentially based on your recommendation but also on our recommendations over a period of 60-90 minutes
3. show the functioning changes and discuss further

# Note
There may be areas of the system that you are more or less familiar with. Please point this out to your interviewer. There is no penalty for not being a React developer if your experience is with Angular or other JS frameworks. Having this knowledge will help to frame our questions and changes we suggest.
