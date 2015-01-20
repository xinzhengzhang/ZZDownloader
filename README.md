ZZDownloader
============

#### Usage
* implement subclass inherit the base class `ZZDownloadBaseEntity` and implement `ZZDownloadParserProtocol`
* implement subclass inherit the base class `ZZDownloadTaskGroup`

```objective-c
SampleEntity *entity = [SampleEntity new];
entity.cid = cid;       
ZZDownloadOperation *operation = [[ZZDownloadOperation alloc] init];
operation.command = ZZDownloadCommandStart;
operation.key = [entity entityKey];
        
[[ZZDownloadTaskManagerV2 shared] addOp:operation withEntity:entity block:nil];
```
#### Operation
| Operation              |  Description          |
|:----------------------:|:---------------------:|
| ZZDownloadCommandStart | start a download task |
| ZZDownloadCommandStop | pause a download task |
| ZZDownloadCommandRemove | remove a download task |
| ZZDownloadCommandCheck | get download task info |
| ZZDownloadCommandCheckAllGroup | get aggregate task list |
| ZZDownloadCommandCheckGroup | get all task under a aggregate key |
| ZZDownloadCommandStartCache | start cache |

#### Notification
| Notification           |  Description          |
|:----------------------:|:---------------------:|
| ZZDownloadTaskNotifyUiNotification | notify task info(progress, state,.....) |
| ZZDownloadTaskDiskSpaceWarningNotification | disk has only 200m left |
| ZZDownloadTaskDiskSpaceErrorNotification | disk has only 50m left (auto stop all task) |
| ZZDownloadTaskNetWorkChangedInterruptNotification | network state changed |
| ZZDownloadTaskNetWorkChangedResumeNotification | network state changed (auto start the task interrupted by the network) |
| ZZDownloadTaskStartTaskUnderCelluar | a download task start under the celluar |

#### Architecture
##### Queue
- opQueue (ZZDownloadOpThread)
	* receive ui operation and serialize it into `ZZDownloadTask`
- downloadQueue (ZZDownloadUrlConnectionQueueName)
	* receive task from opQueue
	* download content from network or local cache
	* progress info will be notified through opQueue
- notifyQueue (ZZDownloadNotifyThread)
	* receive message from opQueue
- backgroundCacheQueue (ZZDownloadUrlSessionOpThread)
	* receive task from opQueue

##### Model
- ZZDownloadTask
	* serializable data saved to disk
- ZZDownloadTaskInfo
	* task info affixed into notification