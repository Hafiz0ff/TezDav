import type { Activity } from '../Database/database';

export type RootStackParamList = {
  Root: undefined;
  Activities: undefined;
  ActivityDetail: { activity: Activity };
};

export type RootTabParamList = {
  Dashboard: undefined;
  Form: undefined;
  Records: undefined;
  Routes: undefined;
  Profile: undefined;
};
