## Effects

### Blocking / Non-blocking

| Name                 | Blocking                                                    |
| -------------------- | ------------------------------------------------------------|
| TakeEvery            | No                                                          |
| TakeLatest           | No                                                          |
| TakeLeading          | No                                                          |
| Throttle             | No                                                          |
| Debounce             | :x:                                                          |
| Retry                | :heavy_check_mark:                                                         |
| Take                 | Yes                                                         |
| TakeMaybe            | Yes                                                         |
| Put                  | No                                                          |
| PutResolve           | Yes                                                         |
| Call                 | Yes                                                         |
| Apply                | Yes                                                         |
| Try                  | Yes                                                         |
| Cps                  | Yes                                                         |
| Fork                 | No                                                          |
| Spawn                | No                                                          |
| Join                 | Yes                                                         |
| Cancel               | No                                                          |
| Select               | No                                                          |
| ActionChannel        | No                                                          |
| Flush                | Yes                                                         |
| Cancelled            | Yes                                                         |
| Race                 | Yes                                                         |
| Delay                | Yes                                                         |
| All                  | Blocks if there is a blocking effect in the array or object |
| Return               | Yes                                                         |

