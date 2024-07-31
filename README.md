# Test Java
## Why the plugin?
This plugin was born from the idea that I couldn't use the [neotest-java](https://github.com/rcasia/neotest-java/issues/127#issue-2425621346) plugin, so I came up with the idea of creating my own plugin that does what I want.

# Usage
This plugin when installed will enable 2 commands:
```
:MavenTestCurrentFile --> This command will run the tests for the entire file in which this.
:MavenTestAtCursor --> This command will execute the test where the cursor is located.
```
## Photos of results
### Running
![][https://imgur.com/ZKaGPj0]
An icon will be displayed at the beginning of running the commands (MavenTestAtCursor, MavenTestCurrentFile) to let you know that it has started.

### Success
![][https://imgur.com/uHy96Ik]
If the test passes the test this icon will be displayed and will show the notification
![][https://imgur.com/JWXZtex]

### Error
![][https://imgur.com/fKZjM34]
If the test fails, this icon will be displayed and will show where the test failed.
![][https://imgur.com/1et2Nxf]
